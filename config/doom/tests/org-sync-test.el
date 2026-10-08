;;; org-sync-test.el --- Sync buffer safety tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'org)
(load-file (expand-file-name "../org-sync.el" (file-name-directory load-file-name)))

(ert-deftest org-sync-defers-incoming-while-buffer-is-modified ()
  (let* ((org-directory (make-temp-file "org-sync-ert" t))
         (file (expand-file-name "note.org.gpg" org-directory))
         (buffer (generate-new-buffer " *org-sync-test*"))
         (my-org-sync--pending nil)
         (called nil))
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (setq buffer-file-name file)
            (insert "unsaved private note"))
          (cl-letf (((symbol-function 'my-org-sync--call) (lambda (&rest _) (setq called t))))
            (my-org-sync--apply '((from . "old") (target . "new"))))
          (should my-org-sync--pending)
          (should-not called))
      (with-current-buffer buffer (set-buffer-modified-p nil))
      (kill-buffer buffer)
      (delete-directory org-directory))))

(ert-deftest org-sync-blocks-editing-stale-buffer ()
  (with-temp-buffer
    (setq-local my-org-sync--needs-reload t)
    (add-hook 'before-change-functions #'my-org-sync--before-change nil t)
    (should-error (insert "change") :type 'user-error)
    (should (equal (buffer-string) ""))))

(ert-deftest org-sync-reload-can-replace-stale-buffer ()
  (let* ((directory (make-temp-file "org-sync-reload" t))
         (file (expand-file-name "note.txt" directory))
         (buffer nil))
    (unwind-protect
        (progn
          (write-region "old" nil file nil 'silent)
          (setq buffer (find-file-noselect file))
          (write-region "new" nil file nil 'silent)
          (with-current-buffer buffer
            (setq-local my-org-sync--needs-reload t)
            (add-hook 'before-change-functions #'my-org-sync--before-change nil t)
            (my-org-sync--refresh)
            (should (equal (buffer-string) "new"))
            (should-not my-org-sync--needs-reload)))
      (when buffer (kill-buffer buffer))
      (delete-directory directory t))))

(ert-deftest org-sync-refuses-to-reload-modified-buffer ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/org-sync-test.org.gpg")
    (insert "unsaved")
    (setq-local my-org-sync--needs-reload t)
    (should-error (my-org-sync--refresh) :type 'user-error)
    (should (equal (buffer-string) "unsaved"))))
