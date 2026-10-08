;;; org-weekly-blocks.el --- Weekly reservations -*- lexical-binding: t; -*-

(require 'org)
(require 'org-agenda)
(require 'org-duration)
(require 'calendar)
(require 'tabulated-list)
(require 'cl-lib)
(require 'subr-x)

(defvar my-org-block-template-file (expand-file-name "weekly-blocks.org.gpg" org-directory))
(defvar my-org-block-file (expand-file-name "blocks.org.gpg" org-directory))
(defvar-local my-org-block-week nil)
(defvar org-timeblock-span 7)
(defvar org-timeblock-daterange nil)
(defvar org-timeblock-scale-options)
(defvar org-timeblock-files)
(defvar org-timeblock-mode-map)
(defvar org-timeblock-list-mode-map)
(defvar my-org-calendar-window-configuration nil)
(declare-function org-timeblock "org-timeblock")
(declare-function org-timeblock-jump-to-day "org-timeblock" (date))
(declare-function org-timeblock-redraw-buffers "org-timeblock")
(declare-function evil-set-initial-state "evil" (mode state))

(defun my-org-block-monday (date)
  "Return the Monday containing ISO DATE, using calendar dates across DST."
  (let* ((parts (mapcar #'string-to-number (split-string date "-")))
         (greg (list (nth 1 parts) (nth 2 parts) (car parts)))
         (absolute (calendar-absolute-from-gregorian greg))
         (monday (calendar-gregorian-from-absolute
                  (- absolute (mod (1- (calendar-day-of-week greg)) 7)))))
    (format "%04d-%02d-%02d" (nth 2 monday) (car monday) (nth 1 monday))))

(defconst my-org-calendar-categories
  '(("work" "Work" "#315A8A")
    ("hobby-projects" "Hobby projects" "#705095")
    ("exercise" "Exercise" "#287568")
    ("golf" "Golf" "#627535")
    ("social" "Social" "#984F70")
    ("errands" "Errands" "#886B2D")
    ("transportation" "Transportation" "#526777")
    ("personal" "Personal" "#965940")
    ("reserved" "Reserved" "#555B66")))

(defvar org-timeblock-tag-colors)
(declare-function org-timeblock-selected-block-marker "org-timeblock")

(defun my-org-calendar-category-tag (tags)
  "Return the most local category in TAGS, or nil."
  (cl-find-if (lambda (tag) (assoc tag my-org-calendar-categories)) (reverse tags)))

(defun my-org-calendar-label (tags)
  "Return the display label for TAGS, defaulting to Reserved."
  (cadr (assoc (or (my-org-calendar-category-tag tags) "reserved")
               my-org-calendar-categories)))

(defun my-org-calendar-read-category (&optional current)
  "Read a category, defaulting to CURRENT or Reserved."
  (let ((choice (completing-read
                 "Label: " (mapcar #'cadr my-org-calendar-categories)
                 nil t nil nil (my-org-calendar-label (list (or current "reserved"))))))
    (car (cl-find choice my-org-calendar-categories :key #'cadr :test #'equal))))

(defun my-org-calendar-set-category (tag)
  "Set the current Org entry's category to TAG, preserving unrelated tags."
  (unless (assoc tag my-org-calendar-categories) (user-error "Unknown label: %s" tag))
  (org-back-to-heading t)
  (org-set-tags (append (cl-remove-if
                        (lambda (old) (assoc old my-org-calendar-categories))
                        (org-get-tags nil t))
                       (list tag))))

(defun my-org-calendar-colors (original tags)
  "Prefer the most local category color, with neutral color for unlabeled entries."
  (or (cdr (assoc (my-org-calendar-category-tag tags) org-timeblock-tag-colors))
      (funcall original tags)
      'my-org-calendar-reserved))

(defun my-org-calendar-list-labels (&rest _)
  "Display category names after entries in the calendar's companion list."
  (when-let* ((buffer (get-buffer "*org-timeblock-list*")))
    (with-current-buffer buffer
      (save-excursion
        (remove-overlays (point-min) (point-max) 'my-org-calendar-label t)
        (goto-char (point-min))
        (while (not (eobp))
          (when (get-text-property (point) 'marker)
            (let* ((label (my-org-calendar-label (get-text-property (point) 'tags)))
                   (end (line-end-position))
                   (overlay (make-overlay end end)))
              (overlay-put overlay 'my-org-calendar-label t)
              (overlay-put overlay 'after-string (propertize (concat " [" label "]") 'face 'shadow))))
          (forward-line 1))))))

(defun my-org-calendar-refresh-views ()
  "Refresh visible calendar and placement views after editing an entry."
  (if (get-buffer-window "*Weekly blocks*")
      (with-current-buffer "*Weekly blocks*" (my-org-block-refresh))
    (when (and (featurep 'org-timeblock)
               (or (get-buffer-window "*org-timeblock*")
                   (get-buffer-window "*org-timeblock-list*")))
      (org-timeblock-redraw-buffers))
    (when-let* ((window (get-buffer-window "*Org Agenda*")))
      (with-selected-window window (org-agenda-redo)))))

(defun my-org-calendar-relabel ()
  "Choose a label for the selected calendar, agenda, planner, or Org entry."
  (interactive)
  (let ((marker
         (cond
          ((derived-mode-p 'org-timeblock-mode) (org-timeblock-selected-block-marker))
          ((derived-mode-p 'org-timeblock-list-mode)
           (get-text-property (line-beginning-position) 'marker))
          ((derived-mode-p 'my-org-block-mode) (tabulated-list-get-id))
          ((derived-mode-p 'org-agenda-mode) (org-get-at-bol 'org-marker))
          ((derived-mode-p 'org-mode) (point-marker)))))
    (unless (and (markerp marker) (marker-buffer marker)) (user-error "Select an entry first"))
    (let ((tag (my-org-calendar-read-category
                (org-with-point-at marker (my-org-calendar-category-tag (org-get-tags))))))
      (org-with-point-at marker
        (my-org-calendar-set-category tag)
        (save-buffer))
      (my-org-calendar-refresh-views)
      (message "Label set to %s" (my-org-calendar-label (list tag))))))

(defun my-org-calendar-setup-colors ()
  "Install the category palette and label displays."
  (dolist (category my-org-calendar-categories)
    (pcase-let ((`(,tag ,label ,color) category))
      (let ((face (intern (concat "my-org-calendar-" tag))))
        (custom-declare-face face `((t (:background ,color :foreground "#F5F5F5")))
                             (concat "Calendar color for " label ".") :group 'org-faces)
        (setf (alist-get tag org-timeblock-tag-colors nil nil #'equal) face))))
  (advice-add 'org-timeblock-get-colors :around #'my-org-calendar-colors)
  (advice-add 'org-timeblock-redraw-buffers :after #'my-org-calendar-list-labels)
  (advice-add 'org-timeblock-list-update-entry :after #'my-org-calendar-list-labels))

(dolist (category my-org-calendar-categories)
  (add-to-list 'org-tag-alist (list (car category)) t))

(defun my-org-block-templates ()
  "Read and validate templates before modifying any week's blocks."
  (with-current-buffer (find-file-noselect my-org-block-template-file)
    (org-with-wide-buffer
     (let (templates keys)
       (org-map-entries
        (lambda ()
          (when-let* ((key (org-entry-get nil "BLOCK_KEY")))
            (let ((count (org-entry-get nil "PER_WEEK"))
                  (duration (org-entry-get nil "MINUTES")))
              (unless (and (string-match-p "\\`[a-z0-9-]+\\'" key)
                           (not (member key keys))
                           count (string-match-p "\\`[0-9]+\\'" count)
                           duration (string-match-p "\\`[0-9]+\\'" duration)
                           (> (string-to-number duration) 0))
                (user-error "Invalid or duplicate template %s; check BLOCK_KEY, PER_WEEK and MINUTES" key))
              (push key keys)
              (push (list key (org-get-heading t t t t)
                          (string-to-number count) (string-to-number duration)
                          (or (my-org-calendar-category-tag (org-get-tags)) "reserved"))
                    templates)))) nil nil)
       (unless templates (user-error "No templates found in %s" my-org-block-template-file))
       (nreverse templates)))))

(defun my-org-block-generate (week)
  "Create missing instances for Monday WEEK; preserve existing entries."
  (let ((templates (my-org-block-templates)) (created 0))
    (with-current-buffer (find-file-noselect my-org-block-file)
      (org-with-wide-buffer
       (let ((existing (make-hash-table :test #'equal)) parent)
         (org-map-entries
          (lambda ()
            (when-let* ((id (org-entry-get nil "BLOCK_INSTANCE")))
              (puthash id t existing))
            (when (and (= (org-outline-level) 1)
                       (equal (org-entry-get nil "BLOCK_WEEK") week))
              (setq parent (point-marker)))) nil nil)
         (atomic-change-group
           (unless parent
             (goto-char (point-max))
             (unless (bolp) (insert "\n"))
             (insert "\n* Week of " week "\n")
             (forward-line -1)
             (org-entry-put nil "BLOCK_WEEK" week)
             (setq parent (point-marker)))
           (dolist (template templates)
             (pcase-let ((`(,key ,title ,count ,minutes ,category) template))
               (dotimes (index count)
                 (let ((id (format "%s/%s/%d" week key (1+ index))))
                   (unless (gethash id existing)
                     (goto-char parent)
                     (org-end-of-subtree t t)
                     (unless (bolp) (insert "\n"))
                     (insert (format "** %s%s :timeblock:\n" title
                                     (if (> count 1) (format " %d" (1+ index)) "")))
                     (forward-line -1)
                     (my-org-calendar-set-category category)
                     (org-entry-put nil "BLOCK_INSTANCE" id)
                     (org-entry-put nil "BLOCK_WEEK" week)
                     (org-entry-put nil "MINUTES" (number-to-string minutes))
                     (org-entry-put nil "EFFORT" (org-duration-from-minutes minutes))
                     (cl-incf created)))))))
         (set-marker parent nil)))
      (when (buffer-modified-p) (save-buffer)))
    created))

(defun my-org-block-timestamp ()
  "Return this entry's active timestamp, excluding child entries."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (save-excursion (outline-next-heading) (point))))
      (when (re-search-forward org-ts-regexp end t)
        (match-string-no-properties 0)))))

(defun my-org-block-entries (week)
  "Return table rows for instances belonging to WEEK."
  (with-current-buffer (find-file-noselect my-org-block-file)
    (org-with-wide-buffer
     (let (rows)
       (org-map-entries
        (lambda ()
          (when (and (org-entry-get nil "BLOCK_INSTANCE")
                     (equal week (org-entry-get nil "BLOCK_WEEK")))
            (let* ((stamp (my-org-block-timestamp))
                   (skipped (equal "skipped" (org-entry-get nil "BLOCK_STATUS"))))
              (push (list (copy-marker (point) t)
                          (vector (org-get-heading t t t t)
                                  (concat (org-entry-get nil "MINUTES") " min")
                                  (cond (stamp "Placed") (skipped "Skipped") (t "Unplaced"))
                                  (or stamp "")
                                  (my-org-calendar-label (org-get-tags)))) rows)))) nil nil)
       (nreverse rows)))))

(defun my-org-block-set-placement (marker start &optional minutes)
  "Place MARKER at START for MINUTES, rejecting dates outside its week."
  (org-with-point-at marker
    (let* ((week (org-entry-get nil "BLOCK_WEEK"))
           (duration (or minutes (string-to-number (org-entry-get nil "MINUTES"))))
           (end (time-add start (* duration 60)))
           (system-time-locale "C"))
      (unless (and (> duration 0)
                   (equal week (my-org-block-monday (format-time-string "%F" start)))
                   (equal week (my-org-block-monday
                                (format-time-string "%F" (time-subtract end 1)))))
        (user-error "The block must fit within the week of %s" week))
      (atomic-change-group
        (my-org-block-clear-time)
        (org-entry-delete nil "BLOCK_STATUS")
        (org-entry-put nil "MINUTES" (number-to-string duration))
        (org-entry-put nil "EFFORT" (org-duration-from-minutes duration))
        (org-end-of-meta-data t)
        (insert (if (equal (format-time-string "%F" start) (format-time-string "%F" end))
                    (format "%s-%s>\n" (format-time-string "<%Y-%m-%d %a %H:%M" start)
                            (format-time-string "%H:%M" end))
                  (format "%s--%s\n" (format-time-string "<%Y-%m-%d %a %H:%M>" start)
                          (format-time-string "<%Y-%m-%d %a %H:%M>" end)))))
      (save-buffer))))

(defun my-org-block-clear-time ()
  "Remove active timestamps in the current block, preserving other text."
  (save-excursion
    (org-back-to-heading t)
    (let ((end (copy-marker (save-excursion (outline-next-heading) (point)))))
      (while (re-search-forward (concat org-ts-regexp "\\(?:--" org-ts-regexp "\\)?") end t)
        (replace-match "" t t))
      (set-marker end nil))))

(defun my-org-block-marker ()
  "Return the block at point or report that no row is selected."
  (or (tabulated-list-get-id) (user-error "Select a block first")))

(defun my-org-block-place ()
  "Place or move the selected block, asking for date, time and duration."
  (interactive)
  (let* ((marker (my-org-block-marker))
         (default (org-with-point-at marker
                    (or (my-org-block-timestamp) (concat (org-entry-get nil "BLOCK_WEEK") " 09:00"))))
         (date (org-read-date nil nil nil "Block date: "
                              (org-time-string-to-time default)))
         (clock (read-string "Start time (HH:MM): "
                             (format-time-string "%H:%M" (org-time-string-to-time default))))
         (minutes (read-number "Duration in minutes: "
                               (org-with-point-at marker
                                 (string-to-number (org-entry-get nil "MINUTES"))))))
    (unless (string-match-p "\\`\\(?:[01][0-9]\\|2[0-3]\\):[0-5][0-9]\\'" clock)
      (user-error "Use a start time such as 17:30"))
    (unless (and (integerp minutes) (> minutes 0))
      (user-error "Duration must be a positive whole number of minutes"))
    (my-org-block-set-placement marker (org-time-string-to-time (concat date " " clock)) minutes)
    (my-org-block-refresh)))

(defun my-org-block-set-status (marker status)
  "Clear MARKER's reservation and set STATUS, or leave it unplaced if nil."
  (org-with-point-at marker
    (atomic-change-group
      (my-org-block-clear-time)
      (if status (org-entry-put nil "BLOCK_STATUS" status)
        (org-entry-delete nil "BLOCK_STATUS")))
    (save-buffer)))

(defun my-org-block-skip ()
  "Skip the selected block for this week only."
  (interactive)
  (my-org-block-set-status (my-org-block-marker) "skipped")
  (my-org-block-refresh))

(defun my-org-block-unplace ()
  "Return the selected block to the unplaced list, including skipped blocks."
  (interactive)
  (my-org-block-set-status (my-org-block-marker) nil)
  (my-org-block-refresh))

(defun my-org-block-visit ()
  "Visit the selected block's Org entry."
  (interactive)
  (let ((marker (my-org-block-marker)))
    (pop-to-buffer (marker-buffer marker))
    (widen)
    (goto-char marker)
    (org-fold-show-context 'agenda)))

(defun my-org-block-refresh ()
  "Refresh this week's list and any visible calendar."
  (interactive)
  (setq tabulated-list-entries (my-org-block-entries my-org-block-week))
  (tabulated-list-print t)
  (let ((unplaced (cl-count "Unplaced" tabulated-list-entries
                            :key (lambda (row) (aref (cadr row) 2)) :test #'equal)))
    (setq header-line-format
          (format "Week of %s | %d unplaced | p place/move  s skip  u unplace  RET source  g refresh  l label  v calendar"
                  my-org-block-week unplaced)))
  (when (get-buffer-window "*org-timeblock*")
    (org-timeblock-redraw-buffers))
  (when-let* ((window (get-buffer-window "*Org Agenda*")))
    (with-selected-window window (org-agenda-redo))))

(defvar my-org-block-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "p") #'my-org-block-place)
    (define-key map (kbd "s") #'my-org-block-skip)
    (define-key map (kbd "u") #'my-org-block-unplace)
    (define-key map (kbd "RET") #'my-org-block-visit)
    (define-key map (kbd "g") #'my-org-block-refresh)
    (define-key map (kbd "l") #'my-org-calendar-relabel)
    (define-key map (kbd "v") #'my-org-block-calendar)
    map))

(define-derived-mode my-org-block-mode tabulated-list-mode "Weekly blocks"
  "Place weekly blocks with p, skip with s, and unplace with u."
  (setq tabulated-list-format [("Block" 26 t) ("Duration" 10 t) ("Status" 10 t) ("When" 30 t) ("Label" 16 t)]
        tabulated-list-padding 1)
  (tabulated-list-init-header))

(defun my-org-calendar-start-date (date)
  "Use Monday for a seven-day view, or DATE for a shorter view."
  (if (= org-timeblock-span 7) (my-org-block-monday date) date))

(defun my-org-calendar-show (date)
  "Display DATE using the current scale and span."
  (let ((week (my-org-calendar-start-date date)))
    (when-let* ((main (cl-find-if (lambda (window)
                                   (not (window-parameter window 'window-side)))
                                 (window-list))))
      (select-window main))
    (delete-other-windows)
    (if (and (display-graphic-p) (image-type-available-p 'svg)
             (require 'org-timeblock nil t))
        (progn
          (org-timeblock)
          (org-timeblock-jump-to-day (decode-time (org-time-string-to-time week))))
      (let ((org-agenda-start-on-weekday nil)
            (org-agenda-window-setup 'current-window))
        (org-agenda-list nil week org-timeblock-span)))))

;;;###autoload
(defun my-org-calendar-week (&optional date)
  "Open this week's calendar without generating blocks.
With a prefix argument, prompt for a date.  DATE can also be an ISO date."
  (interactive (list (when current-prefix-arg
                       (org-read-date nil nil nil "Week containing: "))))
  (unless (derived-mode-p 'org-timeblock-mode 'org-timeblock-list-mode)
    (setq my-org-calendar-window-configuration (current-window-configuration)))
  (my-org-calendar-show (or date (format-time-string "%F"))))

(defun my-org-calendar-quit ()
  "Return to the layout used before opening the standalone calendar."
  (interactive)
  (if (window-configuration-p my-org-calendar-window-configuration)
      (progn
        (set-window-configuration my-org-calendar-window-configuration)
        (setq my-org-calendar-window-configuration nil))
    (quit-window)))

(defun my-org-calendar-move-page (offset)
  "Move by OFFSET pages of the visible day span, including across DST."
  (let* ((date (copy-sequence (car org-timeblock-daterange))))
    (cl-incf (nth 3 date) (* offset org-timeblock-span))
    (setf (nth 7 date) -1 (nth 8 date) nil)
    (org-timeblock-jump-to-day (decode-time (encode-time date)))))

(defun my-org-calendar-next-page ()
  "Show the next span of days."
  (interactive)
  (my-org-calendar-move-page 1))

(defun my-org-calendar-previous-page ()
  "Show the preceding span of days."
  (interactive)
  (my-org-calendar-move-page -1))

(defun my-org-calendar-today ()
  "Show today, or the week containing today in a seven-day view."
  (interactive)
  (org-timeblock-jump-to-day
   (decode-time (org-time-string-to-time
                 (my-org-calendar-start-date (format-time-string "%F"))))))

;; Keep existing M-x commands working after the navigation rename.
(defalias 'my-org-calendar-next-week #'my-org-calendar-next-page)
(defalias 'my-org-calendar-previous-week #'my-org-calendar-previous-page)
(defalias 'my-org-calendar-this-week #'my-org-calendar-today)

(defun my-org-calendar-plan ()
  "Plan blocks for the week currently displayed in the visual calendar."
  (interactive)
  (my-org-plan-week (format-time-string "%F" (encode-time (car org-timeblock-daterange)))))

(defun my-org-calendar-from-agenda ()
  "Open the visual calendar at the date under the agenda cursor."
  (interactive)
  (let ((day (get-text-property (point) 'day)))
    (my-org-calendar-week
     (when (integerp day)
       (pcase-let ((`(,month ,date ,year) (calendar-gregorian-from-absolute day)))
         (format "%04d-%02d-%02d" year month date))))))

(defun my-org-calendar-reserve (title start minutes &optional category)
  "Save a plain reservation with TITLE at START for MINUTES.
CATEGORY is a category tag, defaulting to reserved.
This creates no TODO state, repeater, or weekly template instance."
  (setq category (or category "reserved"))
  (unless (assoc category my-org-calendar-categories) (user-error "Unknown label: %s" category))
  (unless (and (stringp title) (not (string-empty-p (string-trim title)))
               (not (string-match-p "[\n\r]" title))
               (integerp minutes) (> minutes 0))
    (user-error "Provide a single-line title and a positive duration in minutes"))
  (let* ((end (time-add start (* minutes 60)))
         (system-time-locale "C")
         (stamp (if (equal (format-time-string "%F" start) (format-time-string "%F" end))
                    (format "%s-%s>" (format-time-string "<%Y-%m-%d %a %H:%M" start)
                            (format-time-string "%H:%M" end))
                  (format "%s--%s" (format-time-string "<%Y-%m-%d %a %H:%M>" start)
                          (format-time-string "<%Y-%m-%d %a %H:%M>" end)))))
    (with-current-buffer (find-file-noselect my-org-block-file)
      (org-with-wide-buffer
       (atomic-change-group
         (goto-char (point-max))
         (unless (bolp) (insert "\n"))
         (insert (format "\n* %s :timeblock:adhoc:%s:\n%s\n" (string-trim title) category stamp))))
      (save-buffer))
    (add-to-list 'org-agenda-files my-org-block-file)
    stamp))

(defvar org-timeblock-column)

(defun my-org-calendar-reservation-default-date ()
  "Return the selected visual calendar day, agenda day, or today's date."
  (cond
   ((and (derived-mode-p 'org-timeblock-mode 'org-timeblock-list-mode)
         org-timeblock-daterange)
    (let ((day (copy-sequence (car org-timeblock-daterange))))
      (when (and (derived-mode-p 'org-timeblock-mode)
                 (boundp 'org-timeblock-column))
        (cl-incf (nth 3 day) (1- org-timeblock-column)))
      (setf (nth 7 day) -1 (nth 8 day) nil)
      (encode-time day)))
   ((and (derived-mode-p 'org-agenda-mode)
         (integerp (get-text-property (point) 'day)))
    (pcase-let ((`(,month ,day ,year)
                 (calendar-gregorian-from-absolute (get-text-property (point) 'day))))
      (encode-time 0 0 0 day month year)))
   (t (current-time))))

;;;###autoload
(defun my-org-calendar-add-reservation ()
  "Prompt for an ad hoc reservation and refresh any visible calendar."
  (interactive)
  (let* ((default (my-org-calendar-reservation-default-date))
         (title (read-string "Reservation title: " nil nil "Reserved"))
         (category (my-org-calendar-read-category))
         (date (org-read-date nil nil nil "Reservation date: " default))
         (clock (read-string "Start time (HH:MM): "))
         (minutes (read-number "Duration in minutes: " 60)))
    (unless (string-match-p "\\`\\(?:[01][0-9]\\|2[0-3]\\):[0-5][0-9]\\'" clock)
      (user-error "Use a start time such as 17:30"))
    (let ((stamp (my-org-calendar-reserve
                  title (org-time-string-to-time (concat date " " clock)) minutes category)))
      (when (and (featurep 'org-timeblock)
                 (or (get-buffer-window "*org-timeblock*")
                     (get-buffer-window "*org-timeblock-list*")))
        (org-timeblock-redraw-buffers))
      (when-let* ((window (get-buffer-window "*Org Agenda*")))
        (with-selected-window window (org-agenda-redo)))
      (message "Reserved %s %s" title stamp))))

(defun my-org-calendar-header ()
  "Show the visual calendar's navigation and view controls."
  (setq-local header-line-format
              "[ / ] previous/next view   . today   j date   v hours   V days   T all-day/details   + reserve   l label   S sync   P plan   q back"))

(with-eval-after-load 'org-timeblock
  (my-org-calendar-setup-colors)
  (setq org-timeblock-files 'agenda
        org-timeblock-scale-options '(5 . 23))
  (dolist (map (list org-timeblock-mode-map org-timeblock-list-mode-map))
    (define-key map (kbd "[") #'my-org-calendar-previous-page)
    (define-key map (kbd "]") #'my-org-calendar-next-page)
    (define-key map (kbd ".") #'my-org-calendar-today)
    (define-key map (kbd "+") #'my-org-calendar-add-reservation)
    (define-key map (kbd "l") #'my-org-calendar-relabel)
    (define-key map (kbd "P") #'my-org-calendar-plan)
    (define-key map (kbd "q") #'my-org-calendar-quit))
  (add-hook 'org-timeblock-mode-hook #'my-org-calendar-header))

(with-eval-after-load 'org-agenda
  (define-key org-agenda-mode-map (kbd "C-c v") #'my-org-calendar-from-agenda))

(defun my-org-block-calendar ()
  "Open the calendar beside this week's placement list."
  (interactive)
  (let ((week my-org-block-week)
        (list-buffer (current-buffer)))
    (my-org-calendar-show week)
    (select-window (display-buffer-in-side-window
                    list-buffer '((side . bottom) (window-height . 0.3))))))

;;;###autoload
(defun my-org-plan-week (date)
  "Generate missing blocks and plan the week containing DATE.
Default to next week on Sunday, and the current week on other days."
  (interactive
   (list (org-read-date nil nil
                       (if (= (string-to-number (format-time-string "%w")) 0) "+1d" "+0d")
                       "Plan week containing: ")))
  (let* ((week (my-org-block-monday date))
         (created (my-org-block-generate week))
         (buffer (get-buffer-create "*Weekly blocks*")))
    (add-to-list 'org-agenda-files my-org-block-file)
    (with-current-buffer buffer
      (my-org-block-mode)
      (setq my-org-block-week week)
      (my-org-block-refresh))
    (pop-to-buffer buffer)
    (my-org-block-calendar)
    (message "Week of %s: created %d blocks" week created)))

(when (file-exists-p my-org-block-file)
  (add-to-list 'org-agenda-files my-org-block-file))
(with-eval-after-load 'evil
  (evil-set-initial-state 'my-org-block-mode 'emacs)
  (evil-set-initial-state 'org-timeblock-mode 'emacs)
  (evil-set-initial-state 'org-timeblock-list-mode 'emacs))
(provide 'org-weekly-blocks)
