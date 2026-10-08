;;; org-appetite.el -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'org)
(require 'org-agenda)
(require 'org-clock)
(require 'org-duration)
(require 'org-element)
(require 'tabulated-list)

(cl-defstruct my-org-appetite-node
  marker title level parent children budget budget-present done clocks blocks
  spent allocated held pool-spent pool-allocated remaining free flags)

(defvar my-org-appetite-cache (make-hash-table :test #'eq))

(defun my-org-appetite-duration (minutes)
  "Format MINUTES without converting hours to working days."
  (if (null minutes) "-"
    (let ((n (round (abs minutes))))
      (format "%s%d:%02d" (if (< minutes 0) "-" "") (/ n 60) (% n 60)))))

(defun my-org-appetite-flag (node text)
  (cl-pushnew text (my-org-appetite-node-flags node) :test #'equal))

(defun my-org-appetite-interval (timestamp)
  "Return the start/end seconds for a timed TIMESTAMP, or nil."
  (when (and timestamp (org-element-property :hour-start timestamp)
             (org-element-property :hour-end timestamp))
    (let ((start (float-time (org-timestamp-to-time timestamp)))
          (end (float-time (org-timestamp-to-time timestamp t))))
      (when (> end start) (cons start end)))))

(defun my-org-appetite-read-buffer (&optional now)
  "Read task budgets, clock records and time blocks in the current Org file."
  (setq now (or now (float-time)))
  (save-excursion
    (save-restriction
      (widen)
      (let ((tree (org-element-parse-buffer)) nodes stack)
        (org-element-map tree 'headline
          (lambda (headline)
            (goto-char (org-element-property :begin headline))
            (unless (or (org-in-archived-heading-p) (org-in-commented-heading-p))
              (let* ((level (org-element-property :level headline))
                     (raw-budget (org-entry-get nil "APPETITE"))
                     (node (make-my-org-appetite-node
                            :marker (point-marker) :level level
                            :title (org-get-heading t t t t)
                            :budget-present (not (null raw-budget))
                            :done (org-entry-is-done-p) :spent 0 :allocated 0))
                     (section (cl-find-if
                               (lambda (e) (eq (org-element-type e) 'section))
                               (org-element-contents headline)))
                     (scheduled (org-element-property :scheduled headline))
                     timestamps)
                (while (and stack (>= (my-org-appetite-node-level (car stack)) level))
                  (pop stack))
                (setf (my-org-appetite-node-parent node) (car stack))
                (when stack (push node (my-org-appetite-node-children (car stack))))
                (push node stack)
                (push node nodes)
                (when raw-budget
                  (condition-case nil
                      (let ((minutes (org-duration-to-minutes raw-budget)))
                        (when (or (string-empty-p raw-budget) (< minutes 0)) (error "Invalid"))
                        (setf (my-org-appetite-node-budget node) minutes))
                    (error (my-org-appetite-flag node "Invalid APPETITE"))))
                (when section
                  (org-element-map section 'clock
                    (lambda (clock)
                      (let* ((ts (org-element-property :value clock))
                             (interval (my-org-appetite-interval ts)))
                        (cond
                         ((eq (org-element-property :status clock) 'running)
                          (if (and (org-clocking-p)
                                   (eq (marker-buffer org-clock-hd-marker) (current-buffer))
                                   (= (marker-position org-clock-hd-marker)
                                      (marker-position (my-org-appetite-node-marker node))))
                              (setq interval (cons (float-time (org-timestamp-to-time ts)) now))
                            (setq interval nil)
                            (my-org-appetite-flag node "Unclosed clock")))
                         ((not interval)
                          (let ((duration (org-element-property :duration clock)))
                            (when duration
                              (cl-incf (my-org-appetite-node-spent node)
                                       (org-duration-to-minutes duration))))))
                        (when interval
                          (push interval (my-org-appetite-node-clocks node))
                          (cl-incf (my-org-appetite-node-spent node)
                                   (/ (max 0 (- (cdr interval) (car interval))) 60.0))))))
                  (org-element-map section 'timestamp
                    (lambda (ts)
                      (when (and (memq (org-element-property :type ts) '(active active-range))
                                 (not (eq (org-element-type (org-element-property :parent ts))
                                          'planning)))
                        (push ts timestamps)))))
                (when scheduled (push scheduled timestamps))
                (dolist (ts timestamps)
                  (let ((interval (my-org-appetite-interval ts)))
                    (cond
                     ((org-element-property :repeater-type ts)
                      (unless (my-org-appetite-node-done node)
                        (my-org-appetite-flag node "Repeating block: use individual sessions")))
                     (interval
                      (cl-pushnew interval (my-org-appetite-node-blocks node) :test #'equal)
                      (unless (my-org-appetite-node-done node)
                        (cl-incf (my-org-appetite-node-allocated node)
                                 (/ (max 0 (- (cdr interval) (max now (car interval)))) 60.0))))
                     ((and (eq ts scheduled) (not (my-org-appetite-node-done node)))
                      (my-org-appetite-flag node "Scheduled without a duration")))))))))
        (setq nodes (nreverse nodes))
        ;; Descendants are processed before parents; totals never sum twice.
        (dolist (node (reverse nodes))
          (let ((own-spent (my-org-appetite-node-spent node))
                (own-allocated (my-org-appetite-node-allocated node))
                (held 0) (pool-spent 0) (pool-allocated 0))
            (dolist (child (my-org-appetite-node-children node))
              (cl-incf (my-org-appetite-node-spent node) (my-org-appetite-node-spent child))
              (cl-incf (my-org-appetite-node-allocated node) (my-org-appetite-node-allocated child))
              (setf (my-org-appetite-node-clocks node)
                    (append (my-org-appetite-node-clocks child) (my-org-appetite-node-clocks node)))
              (if (my-org-appetite-node-budget child)
                  (cl-incf held (max (my-org-appetite-node-budget child)
                                     (my-org-appetite-node-spent child)))
                (cl-incf held (my-org-appetite-node-held child))
                (cl-incf pool-spent (my-org-appetite-node-pool-spent child))
                (cl-incf pool-allocated (my-org-appetite-node-pool-allocated child))))
            (setf (my-org-appetite-node-held node) held
                  (my-org-appetite-node-pool-spent node) (+ own-spent pool-spent)
                  (my-org-appetite-node-pool-allocated node) (+ own-allocated pool-allocated))
            (when-let* ((budget (my-org-appetite-node-budget node)))
              (let ((remaining (- budget (my-org-appetite-node-spent node)))
                    (free (- budget held own-spent pool-spent)))
                (setf (my-org-appetite-node-remaining node) remaining
                      (my-org-appetite-node-free node) free)
                (when (<= remaining 0) (my-org-appetite-flag node "EXHAUSTED"))
                (when (< free 0) (my-org-appetite-flag node "Reservations exceed budget"))
                (when (or (> (my-org-appetite-node-allocated node) (max 0 remaining))
                          (> (my-org-appetite-node-pool-allocated node) (max 0 free)))
                  (my-org-appetite-flag node "Future sessions exceed available time"))))
            (unless (my-org-appetite-node-done node)
              (dolist (block (my-org-appetite-node-blocks node))
                (when (and (<= (cdr block) now)
                           (not (cl-some (lambda (clock)
                                           (and (< (car clock) (cdr block))
                                                (> (cdr clock) (car block))))
                                         (my-org-appetite-node-clocks node))))
                  (my-org-appetite-flag node "Past session has no recorded work"))))))
        (dolist (node nodes)
          (let ((ancestor (my-org-appetite-node-parent node)))
            (while ancestor
              (when (and (my-org-appetite-node-budget ancestor)
                         (<= (my-org-appetite-node-remaining ancestor) 0))
                (my-org-appetite-flag node "Ancestor appetite exhausted"))
              (setq ancestor (my-org-appetite-node-parent ancestor)))))
        nodes))))

(defun my-org-appetite-nodes ()
  "Return cached accounting for the current buffer, refreshed each minute."
  (let* ((key (list (buffer-chars-modified-tick) (floor (float-time) 60)
                    (and (org-clocking-p) (marker-position org-clock-hd-marker))))
         (cached (gethash (current-buffer) my-org-appetite-cache)))
    (if (equal key (car cached)) (cdr cached)
      (let ((nodes (my-org-appetite-read-buffer)))
        (puthash (current-buffer) (cons key nodes) my-org-appetite-cache)
        nodes))))

(defun my-org-appetite-at-point ()
  (save-excursion
    (org-back-to-heading t)
    (let ((pos (point)))
      (cl-find pos (my-org-appetite-nodes)
               :key (lambda (n) (marker-position (my-org-appetite-node-marker n)))))))

(defun my-org-appetite-in-budget-p (node)
  "Whether NODE has its own appetite or belongs to a budgeted ancestor."
  (let ((cursor node) found)
    (while (and cursor (not found))
      (setq found (my-org-appetite-node-budget-present cursor)
            cursor (my-org-appetite-node-parent cursor)))
    found))

(defun my-org-appetite-skip-unflagged ()
  "Agenda filter for unfinished headings needing an appetite decision."
  (let ((node (my-org-appetite-at-point)))
    (unless (and node (my-org-appetite-in-budget-p node)
                 (not (my-org-appetite-node-done node))
                 (my-org-appetite-node-flags node))
      (save-excursion (outline-next-heading) (point)))))

(defun my-org-appetite-agenda-summary ()
  (if-let* ((node (my-org-appetite-at-point)))
      (concat (when (my-org-appetite-node-budget node)
                (format "[%s/%s spent; %s future] "
                        (my-org-appetite-duration (my-org-appetite-node-spent node))
                        (my-org-appetite-duration (my-org-appetite-node-budget node))
                        (my-org-appetite-duration (my-org-appetite-node-allocated node))))
              (string-join (reverse (my-org-appetite-node-flags node)) "; "))
    ""))

(defun my-org-appetite-set ()
  "Set APPETITE on this heading, reserving time from its nearest budgeted parent."
  (interactive)
  (org-back-to-heading t)
  (let ((input (read-string "Appetite (4:00 or 4h; empty removes reservation): "
                            (org-entry-get nil "APPETITE"))))
    (if (string-empty-p input) (org-entry-delete nil "APPETITE")
      (let ((minutes (org-duration-to-minutes input)))
        (when (< minutes 0) (user-error "Appetite cannot be negative"))
        (org-entry-put nil "APPETITE" (my-org-appetite-duration minutes)))))
  (remhash (current-buffer) my-org-appetite-cache))

(defun my-org-appetite-log-time (start end)
  "Insert a completed human work session into this heading's LOGBOOK."
  (interactive
   (let* ((start (org-read-date t t nil "Session start: "))
          (end (org-read-date t t nil "Session end: " start)))
     (list start end)))
  (org-back-to-heading t)
  (when (org-clocking-p) (user-error "Clock out before recording a manual session"))
  (unless (and (time-less-p start end) (not (time-less-p (current-time) end)))
    (user-error "Use a completed session with its end after its start"))
  ;; Reject accidental duplicate/overlapping manual records in agenda files.
  (let ((a (float-time start)) (b (float-time end))
        (buffers (delete-dups
                  (cons (current-buffer) (mapcar #'find-file-noselect (org-agenda-files t))))))
    (dolist (buffer buffers)
      (with-current-buffer buffer
        (dolist (node (my-org-appetite-nodes))
          (when (cl-some (lambda (clock) (and (< (car clock) b) (> (cdr clock) a)))
                         (my-org-appetite-node-clocks node))
            (user-error "This session overlaps recorded work in %s" (buffer-name)))))))
  (save-excursion
    (let ((org-log-into-drawer "LOGBOOK"))
      (goto-char (org-log-beginning t))
      (insert (format "CLOCK: %s--%s => %s\n"
                      (format-time-string "[%Y-%m-%d %a %H:%M]" start)
                      (format-time-string "[%Y-%m-%d %a %H:%M]" end)
                      (my-org-appetite-duration (/ (float-time (time-subtract end start)) 60))))))
  (remhash (current-buffer) my-org-appetite-cache)
  (message "Recorded session; save the Org file"))

(define-derived-mode my-org-appetite-report-mode tabulated-list-mode "Appetite"
  "Show human time budgets and reservations across agenda files."
  (setq tabulated-list-format
        [("Task" 42 t) ("Appetite" 9 nil) ("Spent" 9 nil) ("Future" 9 nil)
         ("Remaining" 10 nil) ("Reserved" 10 nil) ("Free" 9 nil) ("Attention" 45 nil)])
  (setq tabulated-list-padding 1)
  (setq-local revert-buffer-function (lambda (&rest _) (my-org-appetite-report)))
  (local-set-key (kbd "RET") #'my-org-appetite-report-visit)
  (tabulated-list-init-header))

(defun my-org-appetite-report-visit ()
  (interactive)
  (when-let* ((marker (tabulated-list-get-id)))
    (pop-to-buffer (marker-buffer marker))
    (goto-char marker)
    (org-show-context)
    (org-show-entry)))

(defun my-org-appetite-report ()
  "Display appetite accounting for all agenda files.  RET visits a heading."
  (interactive)
  (clrhash my-org-appetite-cache)
  (let (rows)
    (dolist (file (org-agenda-files t))
      (with-current-buffer (find-file-noselect file)
        (dolist (node (my-org-appetite-nodes))
          (when (and (my-org-appetite-in-budget-p node)
                     (or (my-org-appetite-node-budget-present node)
                    (> (my-org-appetite-node-spent node) 0)
                    (> (my-org-appetite-node-allocated node) 0)
                    (my-org-appetite-node-flags node)))
            (push
             (list (my-org-appetite-node-marker node)
                   (vector
                    (concat (file-name-base file) ": "
                            (make-string (* 2 (1- (my-org-appetite-node-level node))) ?\s)
                            (my-org-appetite-node-title node))
                    (my-org-appetite-duration (my-org-appetite-node-budget node))
                    (my-org-appetite-duration (my-org-appetite-node-spent node))
                    (my-org-appetite-duration (my-org-appetite-node-allocated node))
                    (my-org-appetite-duration (my-org-appetite-node-remaining node))
                    (my-org-appetite-duration (my-org-appetite-node-held node))
                    (my-org-appetite-duration (my-org-appetite-node-free node))
                    (concat (when (my-org-appetite-node-done node) "DONE; ")
                            (string-join (reverse (my-org-appetite-node-flags node)) "; "))))
             rows)))))
    (with-current-buffer (get-buffer-create "*Org Appetite*")
      (my-org-appetite-report-mode)
      (setq tabulated-list-entries (nreverse rows))
      (tabulated-list-print t)
      (pop-to-buffer (current-buffer)))))

(with-eval-after-load 'evil
  (evil-set-initial-state 'my-org-appetite-report-mode 'motion)
  (evil-define-key 'motion my-org-appetite-report-mode-map
    (kbd "RET") #'my-org-appetite-report-visit
    (kbd "g r") #'revert-buffer
    (kbd "q") #'quit-window))

(provide 'org-appetite)
