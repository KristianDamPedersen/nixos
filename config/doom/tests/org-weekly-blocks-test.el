;;; org-weekly-blocks-test.el -*- lexical-binding: t; -*-
(require 'ert)
(load-file (expand-file-name "../org-weekly-blocks.el" (file-name-directory load-file-name)))

(defmacro block-test-with-files (&rest body)
  `(let* ((dir (make-temp-file "weekly-block-test" t))
          (my-org-block-file (expand-file-name "blocks.org" dir))
          (my-org-block-template-file (expand-file-name "templates.org" dir))
          (org-agenda-files (list my-org-block-file)))
     (unwind-protect
         (progn
           (with-temp-file my-org-block-template-file
             (insert "* Workout\n:PROPERTIES:\n:BLOCK_KEY: workout\n:PER_WEEK: 3\n:MINUTES: 60\n:END:\n* Date night\n:PROPERTIES:\n:BLOCK_KEY: date\n:PER_WEEK: 1\n:MINUTES: 180\n:END:\n"))
           ,@body)
       (dolist (file (list my-org-block-file my-org-block-template-file))
         (when-let* ((buffer (get-file-buffer file)))
           (with-current-buffer buffer (set-buffer-modified-p nil))
           (kill-buffer buffer)))
       (delete-directory dir t))))

(ert-deftest block-week-boundaries ()
  (should (equal "2026-09-28" (my-org-block-monday "2026-10-04")))
  (should (equal "2026-10-05" (my-org-block-monday "2026-10-05")))
  (should (equal "2025-12-29" (my-org-block-monday "2026-01-01")))
  (should (equal "2026-10-19" (my-org-block-monday "2026-10-25"))))

(ert-deftest block-generation-preserves-plans-and-history ()
  (block-test-with-files
   (should (= 4 (my-org-block-generate "2026-10-05")))
   (let* ((rows (my-org-block-entries "2026-10-05")) (first (caar rows)))
     (my-org-block-set-placement first (org-time-string-to-time "2026-10-06 17:00"))
     (my-org-block-set-status (car (nth 1 rows)) "skipped")
     (should (= 0 (my-org-block-generate "2026-10-05")))
     (should (equal "<2026-10-06 Tue 17:00-18:00>"
                    (org-with-point-at first (my-org-block-timestamp))))
     (should (equal "Skipped" (aref (cadr (nth 1 (my-org-block-entries "2026-10-05"))) 2)))
     (should (= 4 (my-org-block-generate "2026-10-12")))
     (should (= 4 (length (my-org-block-entries "2026-10-05"))))
     (should (cl-every (lambda (r) (equal "Unplaced" (aref (cadr r) 2)))
                       (my-org-block-entries "2026-10-12"))))))

(ert-deftest block-moving-skipping-restoring-and-agenda ()
  (block-test-with-files
   (my-org-block-generate "2026-10-05")
   (let ((marker (caar (my-org-block-entries "2026-10-05"))))
     (my-org-block-set-placement marker (org-time-string-to-time "2026-10-06 17:00"))
     (my-org-block-set-placement marker (org-time-string-to-time "2026-10-07 09:30") 90)
     (should (equal "<2026-10-07 Wed 09:30-11:00>"
                    (org-with-point-at marker (my-org-block-timestamp))))
     (let ((org-agenda-window-setup 'current-window))
       (org-agenda-list nil "2026-10-05" 7)
       (with-current-buffer "*Org Agenda*"
         (should (string-match-p "Workout 1" (buffer-string)))
         (should-not (string-match-p "Workout 2" (buffer-string)))))
     (my-org-block-set-status marker "skipped")
     (should-not (org-with-point-at marker (my-org-block-timestamp)))
     (my-org-block-set-status marker nil)
     (should (equal "Unplaced" (aref (cadar (my-org-block-entries "2026-10-05")) 2)))
     (should-error (my-org-block-set-placement marker (org-time-string-to-time "2026-10-12 09:00")) :type 'user-error)
     (should-not (org-with-point-at marker (my-org-block-timestamp))))))

(ert-deftest block-overnight-and-end-of-week ()
  (block-test-with-files
   (my-org-block-generate "2026-10-05")
   (let ((marker (caar (my-org-block-entries "2026-10-05"))))
     (my-org-block-set-placement marker (org-time-string-to-time "2026-10-06 23:30") 60)
     (org-with-point-at marker
       (should (search-forward "<2026-10-06 Tue 23:30>--<2026-10-07 Wed 00:30>" nil t)))
     (my-org-block-set-status marker nil)
     (org-with-point-at marker
       (should-not (re-search-forward org-ts-regexp nil t)))
     (my-org-block-set-placement marker (org-time-string-to-time "2026-10-11 23:00") 60)
     (should-error (my-org-block-set-placement marker (org-time-string-to-time "2026-10-11 23:30") 60)
                   :type 'user-error))))

(ert-deftest block-invalid-templates-do-not-write ()
  (block-test-with-files
   (with-current-buffer (find-file-noselect my-org-block-template-file)
     (goto-char (point-max))
     (insert "* Duplicate\n:PROPERTIES:\n:BLOCK_KEY: workout\n:PER_WEEK: 1\n:MINUTES: 60\n:END:\n"))
   (should-error (my-org-block-generate "2026-10-05") :type 'user-error)
   (should-not (file-exists-p my-org-block-file))))

(ert-deftest block-planner-ui ()
  (block-test-with-files
   (save-window-excursion
     (my-org-plan-week "2026-10-07")
     (with-current-buffer "*Weekly blocks*"
       (should (equal my-org-block-week "2026-10-05"))
       (should (= 4 (length tabulated-list-entries)))
       (should (string-match-p "4 unplaced" header-line-format))))))

(ert-deftest block-place-command-defaults-to-selected-week ()
  (block-test-with-files
   (my-org-block-generate "2026-11-02")
   (let ((marker (caar (my-org-block-entries "2026-11-02"))))
     (with-temp-buffer
       (my-org-block-mode)
       (setq my-org-block-week "2026-11-02")
       (cl-letf (((symbol-function 'my-org-block-marker) (lambda () marker))
                 ((symbol-function 'org-read-date)
                  (lambda (_with-time _to-time _from _prompt default &rest _)
                    (should (equal "2026-11-02" (format-time-string "%F" default)))
                    "2026-11-03"))
                 ((symbol-function 'read-string) (lambda (&rest _) "17:30"))
                 ((symbol-function 'read-number) (lambda (&rest _) 60))
                 ((symbol-function 'my-org-block-refresh) #'ignore))
         (my-org-block-place)))
     (should (equal "<2026-11-03 Tue 17:30-18:30>"
                    (org-with-point-at marker (my-org-block-timestamp)))))))

(ert-deftest block-planner-uses-two-panes-with-existing-windows ()
  (block-test-with-files
   (save-window-excursion
     (delete-other-windows)
     (split-window-below)
     (my-org-plan-week "2026-10-05")
     (should (= 2 (length (window-list))))
     (should (get-buffer-window "*Org Agenda*"))
     (should (get-buffer-window "*Weekly blocks*"))
     (my-org-block-calendar)
     (should (= 2 (length (window-list)))))))

(ert-deftest calendar-browsing-does-not-create-blocks ()
  (block-test-with-files
   (setq org-agenda-files nil)
   (save-window-excursion
     (my-org-calendar-week "2026-11-05")
     (should (= 1 (length (window-list))))
     (should (eq major-mode 'org-agenda-mode))
     (should-not (file-exists-p my-org-block-file))
     (my-org-calendar-quit))))

(ert-deftest calendar-retains-visual-scale-and-span ()
  (let ((org-timeblock-span 3)
        (org-timeblock-scale-options '(8 . 22)) target)
    (save-window-excursion
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'image-type-available-p) (lambda (&rest _) t))
                ((symbol-function 'require) (lambda (&rest _) t))
                ((symbol-function 'org-timeblock) #'ignore)
                ((symbol-function 'org-timeblock-jump-to-day) (lambda (day) (setq target day))))
        (my-org-calendar-show "2026-10-08"))
      (should (= org-timeblock-span 3))
      (should (equal org-timeblock-scale-options '(8 . 22)))
      (should (equal "2026-10-08" (format-time-string "%F" (encode-time target)))))))

(ert-deftest calendar-navigation-preserves-local-date-across-dst ()
  (let ((org-timeblock-daterange
         (cons (decode-time (org-time-string-to-time "2026-10-19 00:00")) nil)) target)
    (cl-letf (((symbol-function 'org-timeblock-jump-to-day) (lambda (day) (setq target day))))
      (my-org-calendar-next-page)
      (should (equal "2026-10-26 00:00" (format-time-string "%F %H:%M" (encode-time target)))))))

(ert-deftest calendar-today-respects-visible-span ()
  (let ((fixed (org-time-string-to-time "2026-10-08 12:00"))
        (format-date (symbol-function 'format-time-string)) target)
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (format &optional time zone)
                 (funcall format-date format (or time fixed) zone)))
              ((symbol-function 'org-timeblock-jump-to-day)
               (lambda (day) (setq target day))))
      (dolist (org-timeblock-span '(1 2 3 4 5 6 7))
        (my-org-calendar-today)
        (should (equal (if (= org-timeblock-span 7) "2026-10-05" "2026-10-08")
                       (format-time-string "%F" (encode-time target))))))))

(ert-deftest calendar-paging-respects-visible-span ()
  (dolist (org-timeblock-span '(1 2 3 4 5 6 7))
    (let ((org-timeblock-daterange
           (cons (decode-time (org-time-string-to-time "2026-10-08 00:00")) nil)) target)
      (cl-letf (((symbol-function 'org-timeblock-jump-to-day)
                 (lambda (day) (setq target day))))
        (my-org-calendar-next-page)
        (should (equal (format "2026-10-%02d" (+ 8 org-timeblock-span))
                       (format-time-string "%F" (encode-time target))))
        (my-org-calendar-previous-page)
        (should (equal (format "2026-10-%02d" (- 8 org-timeblock-span))
                       (format-time-string "%F" (encode-time target))))))))

(ert-deftest calendar-reservation-is-an-event-not-a-task-or-template ()
  (block-test-with-files
   (my-org-calendar-reserve "Reserved for dinner" (org-time-string-to-time "2026-10-08 18:00") 90)
   (with-current-buffer (find-file-noselect my-org-block-file)
     (goto-char (point-min))
     (re-search-forward "^\\* ")
     (org-back-to-heading)
     (should-not (org-get-todo-state))
     (should-not (org-entry-get nil "SCHEDULED"))
     (should-not (org-entry-get nil "BLOCK_INSTANCE"))
     (should (equal (my-org-block-timestamp) "<2026-10-08 Thu 18:00-19:30>")))
   (should-not (my-org-block-entries "2026-10-05"))
   (save-window-excursion
     (org-agenda-list nil "2026-10-08" 1)
     (with-current-buffer "*Org Agenda*"
       (should (string-match-p "Reserved for dinner" (buffer-string)))))))

(ert-deftest calendar-reservation-can-cross-week-boundary ()
  (block-test-with-files
   (should (equal "<2026-10-11 Sun 23:30>--<2026-10-12 Mon 00:30>"
                  (my-org-calendar-reserve "Late arrival" (org-time-string-to-time "2026-10-11 23:30") 60)))))

(ert-deftest calendar-reservation-invalid-input-does-not-write ()
  (block-test-with-files
   (dolist (title '("" "  " "Dinner\n* New heading"))
     (should-error (my-org-calendar-reserve title (current-time) 60) :type 'user-error))
   (should-error (my-org-calendar-reserve "Dinner" (current-time) 0) :type 'user-error)
   (should-not (file-exists-p my-org-block-file))))

(ert-deftest calendar-label-preserves-entry-and-replaces-category ()
  (with-temp-buffer
    (org-mode)
    (insert "* Parent :work:\n** Dinner :timeblock:adhoc:golf:friend:\n<2026-10-09 Fri 18:00-19:00>\n")
    (goto-char (point-min))
    (forward-line 1)
    (my-org-calendar-set-category "social")
    (should (equal (org-get-tags nil t) '("timeblock" "adhoc" "friend" "social")))
    (should (equal "Social" (my-org-calendar-label (org-get-tags))))
    (should (equal "<2026-10-09 Fri 18:00-19:00>" (my-org-block-timestamp)))))

(ert-deftest calendar-template-labels-propagate-without-relabeling-existing ()
  (block-test-with-files
   (with-current-buffer (find-file-noselect my-org-block-template-file)
     (goto-char (point-min))
     (my-org-calendar-set-category "exercise"))
   (my-org-block-generate "2026-10-05")
   (should (equal "Exercise" (aref (cadar (my-org-block-entries "2026-10-05")) 4)))
   (with-current-buffer (find-file-noselect my-org-block-template-file)
     (goto-char (point-min))
     (my-org-calendar-set-category "golf"))
   (my-org-block-generate "2026-10-05")
   (my-org-block-generate "2026-10-12")
   (should (equal "Exercise" (aref (cadar (my-org-block-entries "2026-10-05")) 4)))
   (should (equal "Golf" (aref (cadar (my-org-block-entries "2026-10-12")) 4)))))

(ert-deftest calendar-reservation-saves-selected-label ()
  (block-test-with-files
   (my-org-calendar-reserve "Train" (org-time-string-to-time "2026-10-09 18:00") 60 "transportation")
   (with-current-buffer (find-file-noselect my-org-block-file)
     (goto-char (point-min))
     (re-search-forward "^\\* ")
     (should (member "transportation" (org-get-tags nil t))))))

(ert-deftest calendar-label-palette-and-companion-list ()
  (require 'org-timeblock)
  (dolist (category my-org-calendar-categories)
    (let ((face (org-timeblock-get-colors (list (car category)))))
      (should (equal (nth 2 category) (face-attribute face :background)))
      (should (equal "#F5F5F5" (face-attribute face :foreground)))))
  (should (eq 'my-org-calendar-reserved (org-timeblock-get-colors '("adhoc"))))
  (should (eq 'my-org-calendar-personal (org-timeblock-get-colors '("work" "personal"))))
  (block-test-with-files
   (my-org-calendar-reserve "Train" (org-time-string-to-time "2026-10-09 18:00") 60 "transportation")
   (let ((org-timeblock-daterange
          (cons (decode-time (org-time-string-to-time "2026-10-09"))
                (decode-time (org-time-string-to-time "2026-10-09")))))
     (org-timeblock-redraw-buffers)
     (with-current-buffer "*org-timeblock-list*"
       (should (cl-find " [Transportation]" (overlays-in (point-min) (point-max))
                        :key (lambda (overlay) (overlay-get overlay 'after-string)) :test #'equal))))))
