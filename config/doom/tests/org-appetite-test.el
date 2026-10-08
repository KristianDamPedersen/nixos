;;; org-appetite-test.el -*- lexical-binding: t; -*-

(require 'ert)
(load (expand-file-name "../org-appetite.el"
                        (file-name-directory (or load-file-name buffer-file-name))) nil t)
(defmacro after! (_feature &rest body) `(progn ,@body))
(load (expand-file-name "../org-planning.el"
                        (file-name-directory (or load-file-name buffer-file-name))) nil t)

(defconst appetite-test-now (float-time (encode-time 0 0 12 3 10 2026)))

(defun appetite-test-parse (text)
  (with-temp-buffer
    (org-mode)
    (setq-local org-todo-keywords '((sequence "TODO" "STRT" "WAIT" "IDEA" "|" "DONE")))
    (org-set-regexps-and-options)
    (insert text)
    (my-org-appetite-read-buffer appetite-test-now)))

(ert-deftest appetite-nested-reservations-count-time-once ()
  (let* ((nodes (appetite-test-parse
                (concat "* TODO Root\n:PROPERTIES:\n:APPETITE: 4:00\n:END:\n"
                        "CLOCK: [2026-10-01 Thu 09:00]--[2026-10-01 Thu 09:30] => 0:30\n"
                        "** Group without budget\n"
                        "*** TODO Child\n:PROPERTIES:\n:APPETITE: 2:00\n:END:\n"
                        "CLOCK: [2026-10-01 Thu 10:00]--[2026-10-01 Thu 10:30] => 0:30\n"
                        "**** TODO Grandchild\n:PROPERTIES:\n:APPETITE: 1:00\n:END:\n"
                        "CLOCK: [2026-10-01 Thu 11:00]--[2026-10-01 Thu 11:45] => 0:45\n")))
         (root (car nodes)) (child (nth 2 nodes)))
    (should (= (my-org-appetite-node-spent root) 105))
    (should (= (my-org-appetite-node-spent child) 75))
    (should (= (my-org-appetite-node-held root) 120))
    (should (= (my-org-appetite-node-held child) 60))
    (should (= (my-org-appetite-node-free root) 90))
    (should (= (my-org-appetite-node-free child) 30))))

(ert-deftest appetite-reservations-limit-parent-session-allocation ()
  (let ((root (car (appetite-test-parse
                    (concat "* TODO Root\nSCHEDULED: <2026-10-05 Mon 10:00-12:00>\n"
                            ":PROPERTIES:\n:APPETITE: 4:00\n:END:\n"
                            "** TODO Child\n:PROPERTIES:\n:APPETITE: 3:00\n:END:\n")))))
    (should (= (my-org-appetite-node-allocated root) 120))
    (should (= (my-org-appetite-node-free root) 60))
    (should (member "Future sessions exceed available time" (my-org-appetite-node-flags root)))))

(ert-deftest appetite-exhausted-ancestor-and-child-overrun ()
  (let* ((nodes (appetite-test-parse
                (concat "* TODO Root\n:PROPERTIES:\n:APPETITE: 1:00\n:END:\n"
                        "** TODO Child\n:PROPERTIES:\n:APPETITE: 0:30\n:END:\n"
                        "CLOCK: [2026-10-01 Thu 10:00]--[2026-10-01 Thu 11:30] => 1:30\n")))
         (root (car nodes)) (child (cadr nodes)))
    (should (= (my-org-appetite-node-held root) 90))
    (should (= (my-org-appetite-node-remaining root) -30))
    (should (member "EXHAUSTED" (my-org-appetite-node-flags root)))
    (should (member "Ancestor appetite exhausted" (my-org-appetite-node-flags child)))))

(ert-deftest appetite-calendar-is-not-actual-work ()
  (let* ((nodes (appetite-test-parse
                (concat "* TODO Past\nSCHEDULED: <2026-10-02 Fri 10:00-12:00>\n"
                        "* TODO Recorded\nSCHEDULED: <2026-10-02 Fri 13:00-14:00>\n"
                        "CLOCK: [2026-10-02 Fri 13:00]--[2026-10-02 Fri 13:30] => 0:30\n"
                        "* TODO Future\nDEADLINE: <2026-10-07 Wed 10:00-12:00>\n"
                        "<2026-10-05 Mon 10:00-11:00>\n"
                        "* TODO Date only\nSCHEDULED: <2026-10-05 Mon>\n"))))
    (should (= (my-org-appetite-node-spent (car nodes)) 0))
    (should (= (my-org-appetite-node-allocated (car nodes)) 0))
    (should (member "Past session has no recorded work" (my-org-appetite-node-flags (car nodes))))
    (should-not (my-org-appetite-node-flags (cadr nodes)))
    (should (= (my-org-appetite-node-allocated (nth 2 nodes)) 60))
    (should (= (my-org-appetite-node-allocated (nth 3 nodes)) 0))))

(ert-deftest appetite-done-children-keep-spent-and-reservations ()
  (let* ((nodes (appetite-test-parse
                (concat "* TODO Root\n:PROPERTIES:\n:APPETITE: 4:00\n:END:\n"
                        "** DONE Child\nSCHEDULED: <2026-10-05 Mon 10:00-12:00>\n"
                        ":PROPERTIES:\n:APPETITE: 2:00\n:END:\n"
                        "CLOCK: [2026-10-01 Thu 10:00]--[2026-10-01 Thu 11:00] => 1:00\n")))
         (root (car nodes)))
    (should (= (my-org-appetite-node-spent root) 60))
    (should (= (my-org-appetite-node-held root) 120))
    (should (= (my-org-appetite-node-allocated root) 0))))

(ert-deftest appetite-invalid-and-repeating-input-is-visible ()
  (let ((node (car (appetite-test-parse
                   "* TODO Repeat\nSCHEDULED: <2026-10-05 Mon 10:00-11:00 +1w>\n:PROPERTIES:\n:APPETITE: nonsense\n:END:\n"))))
    (should (member "Invalid APPETITE" (my-org-appetite-node-flags node)))
    (should (member "Repeating block: use individual sessions" (my-org-appetite-node-flags node)))))

(ert-deftest appetite-manual-session-is-an-org-clock-and-rejects-overlap ()
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Task\n")
    (goto-char (point-min))
    (let ((org-agenda-files nil)
          (start (encode-time 0 0 10 1 10 2026))
          (end (encode-time 0 30 10 1 10 2026)))
      (my-org-appetite-log-time start end)
      (should (string-match-p ":LOGBOOK:" (buffer-string)))
      (should (= (my-org-appetite-node-spent (car (my-org-appetite-read-buffer appetite-test-now))) 30))
      (should-error (my-org-appetite-log-time start end) :type 'user-error))))

(ert-deftest appetite-combined-agenda-includes-attention-without-losing-backlog ()
  (let* ((file (make-temp-file "org-appetite-test-" nil ".org"))
         (org-agenda-files (list file))
         (org-agenda-window-setup 'current-window))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "* TODO [#A] NEEDS-TIME\n"
                    "* TODO [#A] BUDGET-EXCEEDED :planned:\n"
                    ":PROPERTIES:\n:APPETITE: 0:15\n:END:\n"
                    "CLOCK: [2026-10-01 Thu 10:00]--[2026-10-01 Thu 10:30] => 0:30\n"))
          (org-agenda nil "b")
          (should (string-match-p "Appetite needs attention" (buffer-string)))
          (should (string-match-p "EXHAUSTED" (buffer-string)))
          (should (string-match-p "NEEDS-TIME" (buffer-string)))
          (my-org-appetite-report)
          (with-current-buffer "*Org Appetite*"
            (should (= (length tabulated-list-entries) 1))))
      (when-let* ((buffer (get-file-buffer file))) (kill-buffer buffer))
      (delete-file file))))

(ert-deftest appetite-running-clock-counts-toward-ancestors ()
  (with-temp-buffer
    (org-mode)
    (insert "* TODO Root\n:PROPERTIES:\n:APPETITE: 4:00\n:END:\n"
            "** TODO Child\nCLOCK: [2026-10-03 Sat 11:00]\n")
    (goto-char (point-min))
    (re-search-forward "^\\*\\* TODO")
    (beginning-of-line)
    (let ((org-clock-hd-marker (point-marker))
          (org-clock-marker (copy-marker (line-end-position))))
      (let ((nodes (my-org-appetite-read-buffer appetite-test-now)))
        (should (= (my-org-appetite-node-spent (car nodes)) 60))
        (should (= (my-org-appetite-node-spent (cadr nodes)) 60))))))

(ert-deftest appetite-parent-reservations-can-exceed-budget-without-spending ()
  (let ((root (car (appetite-test-parse
                   (concat "* TODO Root\n:PROPERTIES:\n:APPETITE: 4:00\n:END:\n"
                           "** TODO A\n:PROPERTIES:\n:APPETITE: 3:00\n:END:\n"
                           "** TODO B\n:PROPERTIES:\n:APPETITE: 2:00\n:END:\n")))))
    (should (= (my-org-appetite-node-spent root) 0))
    (should (= (my-org-appetite-node-held root) 300))
    (should (member "Reservations exceed budget" (my-org-appetite-node-flags root)))))
