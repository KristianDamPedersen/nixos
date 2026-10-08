;;; test.el -*- lexical-binding: t; -*-
(require 'ert)
(load-file (expand-file-name "../org-google-calendar.el" (file-name-directory load-file-name)))

(defmacro google-test-buffer (text &rest body)
  `(with-temp-buffer
     (org-mode) (insert ,text) (goto-char (point-min)) ,@body))

(ert-deftest google-preparation-preserves-plain-time-and-description ()
  (google-test-buffer "* Dinner :timeblock:social:\n<2026-10-09 Fri 18:00-19:00>\nKeep this note.\n"
    (my-org-google-prepare-entry "calendar@example.invalid")
    (let ((data (org-gcal--get-time-and-desc)) (first (buffer-string)))
      (should (time-equal-p (org-time-string-to-time "2026-10-09 18:00") (date-to-time (plist-get data :start))))
      (should (time-equal-p (org-time-string-to-time "2026-10-09 19:00") (date-to-time (plist-get data :end))))
      (should (string-match-p "Keep this note" first))
      (my-org-google-prepare-entry "calendar@example.invalid")
      (should (equal first (buffer-string)))
      (should (equal "org" (org-entry-get nil org-gcal-managed-property))))))

(ert-deftest google-preparation-preserves-scheduled-task ()
  (google-test-buffer "* TODO Work\nSCHEDULED: <2026-10-09 Fri 10:00-11:00>\n"
    (my-org-google-prepare-entry "calendar@example.invalid")
    (should (equal "<2026-10-09 Fri 10:00-11:00>" (org-entry-get nil "SCHEDULED")))
    (should (time-equal-p (org-time-string-to-time "2026-10-09 10:00") (date-to-time (plist-get (org-gcal--get-time-and-desc) :start))))))

(ert-deftest google-selection-excludes-unplaced-untimed-done-and-imported ()
  (cl-letf (((symbol-function 'org-gcal--up-time) (lambda () (org-time-string-to-time "2026-10-01")))
            ((symbol-function 'org-gcal--down-time) (lambda () (org-time-string-to-time "2026-11-01"))))
    (dolist (text '("* Workout :timeblock:\n"
                    "* TODO Call\nSCHEDULED: <2026-10-09 Fri>\n"
                    "* TODO Call\nSCHEDULED: <2026-10-09 Fri 10:00>\n"
                    "* DONE Call\nSCHEDULED: <2026-10-09 Fri 10:00-11:00>\n"
                    "* Meeting\n:PROPERTIES:\n:org-gcal-managed: gcal\n:END:\n<2026-10-09 Fri 10:00-11:00>\n"))
      (google-test-buffer text (should-not (my-org-google-exportable-p))))
    (google-test-buffer "* Reservation :timeblock:\n<2026-10-09 Fri 10:00-11:00>\n"
      (should (my-org-google-exportable-p)))
    (google-test-buffer "* TODO Call\nSCHEDULED: <2026-10-09 Fri 10:00-11:00>\n"
      (should (my-org-google-exportable-p)))))

(ert-deftest google-offline-sync-orders-posts-before-fetch-and-releases-lock ()
  (let* ((dir (make-temp-file "google-offline-test" t))
         (file (expand-file-name "blocks.org" dir))
         (org-agenda-files (list file))
         (org-gcal-fetch-file-alist (list (cons "calendar@example.invalid" (expand-file-name "calendar.org" dir))))
         (org-gcal--sync-lock nil) (my-org-google-sync-running nil) fail-post calls)
    (unwind-protect
        (progn
          (with-temp-file file (insert "* Dinner :timeblock:\n<2026-10-09 Fri 18:00-19:00>\n"))
          (cl-letf (((symbol-function 'org-gcal--up-time) (lambda () (org-time-string-to-time "2026-10-01")))
                    ((symbol-function 'org-gcal--down-time) (lambda () (org-time-string-to-time "2026-11-01")))
                    ((symbol-function 'org-gcal-post-at-point)
                     (lambda (&rest _) (push 'post calls) (if fail-post (error "Simulated offline failure") (deferred:succeed nil))))
                    ((symbol-function 'org-gcal--sync-calendar)
                     (lambda (&rest _) (push 'fetch calls) (deferred:succeed nil)))
                    ((symbol-function 'org-generic-id-update-id-locations) #'ignore))
            (deferred:sync! (my-org-google-sync))
            (should (equal '(fetch post) calls))
            (setq fail-post t calls nil)
            (cl-letf (((symbol-function 'display-warning) (lambda (&rest _) (push 'warning calls))))
              (deferred:sync! (my-org-google-sync))))
          (should (equal '(warning post) calls))
          (should-not org-gcal--sync-lock)
          (should-not my-org-google-sync-running))
      (when-let* ((buffer (get-file-buffer file))) (kill-buffer buffer))
      (delete-directory dir t))))
