;;; org-google-calendar.el --- Explicit calendar sync -*- lexical-binding: t; -*-
(require 'org)
(require 'org-element)
(require 'deferred)
(require 'cl-lib)

(defvar my-org-google-sync-running nil)
(defvar org-timeblock-mode-map)
(defvar org-timeblock-list-mode-map)
(declare-function my-org-calendar-refresh-views "org-weekly-blocks")
(declare-function org-timeblock-selected-block-marker "org-timeblock")

(defun my-org-google-timestamp ()
  "Return the current entry's scheduled or plain active timestamp."
  (or (org-element-property :scheduled (org-element-at-point))
      (save-excursion
        (let ((end (save-excursion (outline-next-heading) (point))))
          (when (re-search-forward org-ts-regexp end t)
            (goto-char (match-beginning 0))
            (org-element-timestamp-parser))))))

(defun my-org-google-exportable-p ()
  "Return non-nil for a local reservation or timed task in the sync window."
  (let* ((managed (org-entry-get nil org-gcal-managed-property))
         (block (member "timeblock" (org-get-tags)))
         (task (and (member (org-get-todo-state) org-not-done-keywords)
                    (org-entry-get nil "SCHEDULED")))
         (stamp (my-org-google-timestamp)))
    (and (not (equal managed "gcal"))
         (or block task (equal managed "org"))
         (not (equal (org-entry-get nil "BLOCK_STATUS") "skipped"))
         stamp (org-element-property :hour-start stamp)
         (org-element-property :hour-end stamp)
         (not (org-element-property :repeater-type stamp))
         (let ((start (org-timestamp-to-time stamp))
               (end (org-timestamp-to-time stamp t)))
           (and (time-less-p start end)
                (not (time-less-p start (org-gcal--up-time)))
                (not (time-less-p (org-gcal--down-time) end)))))))

(defun my-org-google-prepare-entry (calendar-id)
  "Prepare this entry for CALENDAR-ID without making a network request.
Move plain timestamps into the org-gcal drawer so they remain visible
in Org and readable by org-gcal.  Scheduled timestamps remain in place."
  (org-back-to-heading t)
  (let* ((heading (point-marker))
         (stamp (my-org-google-timestamp))
         (scheduled (org-entry-get nil "SCHEDULED"))
         (raw (and stamp (org-element-property :raw-value stamp)))
         (drawer (save-excursion
                   (re-search-forward "^[ \t]*:org-gcal:[ \t]*$"
                                      (save-excursion (outline-next-heading) (point)) t)))
         (inside (and stamp drawer
                      (> (org-element-property :begin stamp) drawer)
                      (save-excursion
                        (goto-char drawer)
                        (re-search-forward "^[ \t]*:END:[ \t]*$" nil t)
                        (< (org-element-property :begin stamp) (point))))))
    (unless stamp (user-error "This entry has no calendar time"))
    (atomic-change-group
      (unless (or scheduled inside)
        (delete-region (org-element-property :begin stamp)
                       (+ (org-element-property :begin stamp) (length raw))))
      (goto-char heading)
      (org-entry-put nil org-gcal-calendar-id-property
                     (or (org-entry-get nil org-gcal-calendar-id-property) calendar-id))
      (org-entry-put nil org-gcal-managed-property "org")
      (goto-char heading)
      (unless (or scheduled inside)
        (if (re-search-forward "^[ \t]*:org-gcal:[ \t]*$"
                               (save-excursion (outline-next-heading) (point)) t)
            (progn (forward-line 1) (insert raw "\n"))
          (goto-char heading)
          (org-end-of-meta-data t)
          (insert ":org-gcal:\n" raw "\n:END:\n"))))
    (goto-char heading)
    (set-marker heading nil)))

(defun my-org-google-save-files (files)
  "Save modified FILES already visited by Emacs."
  (dolist (file files)
    (when-let* ((buffer (get-file-buffer file)))
      (with-current-buffer buffer
        (when (buffer-modified-p) (save-buffer))))))

(defun my-org-google-sync ()
  "Publish local time reservations, then fetch configured Google calendars.
Only explicit timed ranges within org-gcal's date window are exported.
Untimed tasks, unplaced blocks and repeated Org timestamps remain local."
  (interactive)
  (my-google-calendar-ensure-credentials)
  (when (or my-org-google-sync-running org-gcal--sync-lock)
    (user-error "A Google Calendar sync is already running"))
  (unless org-gcal-fetch-file-alist (user-error "No Google calendar is configured"))
  (let* ((calendars (copy-tree org-gcal-fetch-file-alist))
         (calendar-id (if (= (length calendars) 1) (caar calendars)
                        (completing-read "Export to calendar: " (mapcar #'car calendars) nil t)))
         (files (delete-dups (append (org-agenda-files)
                                    (mapcar (lambda (entry) (expand-file-name (cdr entry))) calendars))))
         markers)
    (dolist (file (org-agenda-files))
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
         (org-map-entries
          (lambda ()
            (when (my-org-google-exportable-p)
              (push (copy-marker (point) t) markers))) nil nil))))
    (setq markers (nreverse markers))
    (setq my-org-google-sync-running t)
    (org-gcal--sync-lock)
    (message "Syncing %d local time reservations with Google Calendar..." (length markers))
    (deferred:try
      (deferred:$
        (deferred:loop markers
          (lambda (marker)
            (org-with-point-at marker
              (my-org-google-prepare-entry calendar-id)
              ;; Persist a returned remote ID before posting the next entry.
              (deferred:nextc (org-gcal-post-at-point)
                (lambda (_)
                  (my-org-google-save-files files))))))
        (deferred:nextc it
          (lambda (_)
            (org-generic-id-update-id-locations org-gcal-entry-id-property)
            ;; Fetch serially.  The package's bulk sync starts independent
            ;; buffer syncs, which can race its shared sync lock.
            (deferred:loop calendars
              (lambda (calendar)
                (org-gcal--sync-calendar calendar t t
                                         (org-gcal--up-time) (org-gcal--down-time))))))
        (deferred:nextc it
          (lambda (_)
            (my-org-google-save-files files)
            (when (fboundp 'my-org-calendar-refresh-views) (my-org-calendar-refresh-views))
            (message "Google Calendar sync complete (%d local reservations checked)" (length markers)))))
      :catch (lambda (error-data)
               (display-warning 'my-org-google-sync (format "Sync failed: %S" error-data) :error))
      :finally (lambda (&rest _)
                 (unwind-protect
                     (my-org-google-save-files files)
                   (setq my-org-google-sync-running nil)
                   (org-gcal--sync-unlock)
                   (dolist (marker markers) (set-marker marker nil)))))))

(defun my-org-google-delete-event ()
  "Remove the selected event from Google, using org-gcal's confirmation."
  (interactive)
  (my-google-calendar-ensure-credentials)
  (when (or my-org-google-sync-running org-gcal--sync-lock)
    (user-error "Wait for the current calendar sync to finish"))
  (let ((marker (cond
                 ((derived-mode-p 'org-timeblock-mode) (org-timeblock-selected-block-marker))
                 ((derived-mode-p 'org-timeblock-list-mode) (get-text-property (line-beginning-position) 'marker))
                 ((derived-mode-p 'my-org-block-mode) (tabulated-list-get-id))
                 ((derived-mode-p 'org-agenda-mode) (org-get-at-bol 'org-marker))
                 ((derived-mode-p 'org-mode) (point-marker)))))
    (unless (and (markerp marker) (marker-buffer marker)) (user-error "Select an event first"))
    (org-with-point-at marker
      (unless (org-entry-get nil org-gcal-entry-id-property)
        (user-error "This entry has not been published to Google Calendar"))
      (let ((buffer (current-buffer)))
        (deferred:nextc (org-gcal-delete-at-point)
          (lambda (_)
            (when (buffer-live-p buffer)
              (with-current-buffer buffer (save-buffer)))
            (when (fboundp 'my-org-calendar-refresh-views) (my-org-calendar-refresh-views))))))))

(with-eval-after-load 'org-timeblock
  (dolist (map (list org-timeblock-mode-map org-timeblock-list-mode-map))
    (define-key map (kbd "S") #'my-org-google-sync)
    (define-key map (kbd "D") #'my-org-google-delete-event)))
(provide 'org-google-calendar)
