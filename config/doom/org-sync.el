;;; org-sync.el --- Background Git sync for encrypted Org -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'epg)
(defvar org-directory)
(defvar my-org-sync-mode)
(defvar ediff-buffer-C)
(declare-function my-org-configure-encryption "org-encryption")

(defgroup my-org-sync nil "Encrypted Org synchronization." :group 'org)
(defcustom my-org-sync-interval 60 "Seconds between background attempts." :type 'integer)
(defcustom my-org-sync-idle-delay 10 "Seconds idle before a sync can start." :type 'integer)
(defvar my-org-sync-script
  (expand-file-name "bin/org-sync.py" (file-name-directory (or load-file-name buffer-file-name))))
(defvar my-org-sync--process nil)
(defvar my-org-sync--timer nil)
(defvar my-org-sync--last-message nil)
(defvar my-org-sync--pending nil)
(defvar my-org-sync--resolution-directory nil)
(defvar my-org-sync--resolution-pr nil)
(defvar my-org-sync--resolution-path nil)
(defvar my-org-sync--resolution-sources nil)

(defun my-org-sync--root () (file-name-as-directory (expand-file-name org-directory)))

(defun my-org-sync--buffers ()
  "Return buffers visiting files under the managed Org directory."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (and buffer-file-name (not (file-remote-p buffer-file-name))
            (file-in-directory-p buffer-file-name (my-org-sync--root)))))
   (buffer-list)))

(defun my-org-sync--modified-p ()
  (cl-some #'buffer-modified-p (my-org-sync--buffers)))

(defun my-org-sync--notify (message-text)
  (unless (equal message-text my-org-sync--last-message)
    (setq my-org-sync--last-message message-text)
    (message "Org sync: %s" message-text)))

(defun my-org-sync--call (&rest arguments)
  "Run a short local worker operation synchronously and return its JSON result."
  (with-temp-buffer
    (let ((status (apply #'call-process "python3" nil t nil my-org-sync-script
                         "--root" (my-org-sync--root) arguments)))
      (goto-char (point-min))
      (let ((result (json-parse-buffer :object-type 'alist :array-type 'list)))
        (unless (eq status 0)
          (error "%s" (alist-get 'message result)))
        result))))

(defun my-org-sync--apply (result)
  "Apply RESULT only while Emacs cannot edit the managed files."
  (if (my-org-sync--modified-p)
      (progn (setq my-org-sync--pending result)
             (my-org-sync--notify "Incoming changes wait for unsaved Org buffers"))
    ;; call-process blocks editing briefly; network work has already finished.
    ;; The worker also verifies HEAD and the saved files before changing anything.
    (let ((buffers (my-org-sync--buffers)))
      (my-org-sync--call "apply" (alist-get 'from result) (alist-get 'target result))
      (setq my-org-sync--pending nil)
      (dolist (buffer buffers)
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (unless (verify-visited-file-modtime buffer)
              ;; Reload on next visit, so background sync never opens a pinentry prompt.
              (setq-local my-org-sync--needs-reload t)))))
      (my-org-sync--notify "Incoming changes applied; changed buffers reload when visited"))))

(defvar-local my-org-sync--needs-reload nil)
(defun my-org-sync--refresh ()
  (when (and my-org-sync--needs-reload buffer-file-name)
    (if (buffer-modified-p)
        (user-error "Org file changed during sync; preserve your edits before reloading")
      (if (file-exists-p buffer-file-name)
          (let ((inhibit-modification-hooks t))
            (revert-buffer t t t) (setq my-org-sync--needs-reload nil))
        (user-error "Org file was deleted remotely; this buffer retains the old contents")))))

(defun my-org-sync--before-change (&rest _)
  ;; Never edit stale decrypted contents after an incoming file update.
  (when my-org-sync--needs-reload
    (user-error "Org file changed during sync; run M-x my-org-sync-refresh-buffer")))

(defun my-org-sync-refresh-buffer ()
  "Reload the current buffer after an incoming encrypted file update."
  (interactive)
  (my-org-sync--refresh))

(defun my-org-sync--protect-buffer ()
  (when (and buffer-file-name (not (file-remote-p buffer-file-name))
             (file-in-directory-p buffer-file-name (my-org-sync--root)))
    (add-hook 'before-change-functions #'my-org-sync--before-change nil t)
    (add-hook 'before-save-hook #'my-org-sync--refresh nil t)))

(defun my-org-sync--handle (result)
  (let ((status (alist-get 'status result)) (conflicts (alist-get 'conflicts result)))
    (cond ((equal status "apply") (my-org-sync--apply result))
          ((equal status "error") (my-org-sync--notify (alist-get 'message result)))
          ((equal status "synced") (my-org-sync--notify "Saved changes are synchronized"))
          ((equal status "resolved")
           (setq my-org-sync--resolution-directory nil
                 my-org-sync--resolution-pr nil
                 my-org-sync--resolution-path nil)
           (my-org-sync--notify (alist-get 'message result)))
          ((equal status "resolution")
           (setq my-org-sync--resolution-directory (alist-get 'directory result))
           (my-org-sync--notify "Resolution prepared; run M-x my-org-sync-resolve-file"))
          (t (my-org-sync--notify (or (alist-get 'message result) status))))
    (when conflicts
      (my-org-sync--notify
       (format "Conflicts need local resolution: %s"
               (mapconcat (lambda (pr) (alist-get 'url pr)) conflicts ", "))))))

(defun my-org-sync--start (&rest arguments)
  (when (process-live-p my-org-sync--process)
    (user-error "Org sync is already running"))
  (let ((buffer (generate-new-buffer " *org-sync-worker*")))
    (setq my-org-sync--process
          (make-process
           :name "org-sync" :buffer buffer :noquery t :connection-type 'pipe
           :command (append (list "python3" my-org-sync-script "--root" (my-org-sync--root)) arguments)
           :sentinel
           (lambda (process _event)
             (when (memq (process-status process) '(exit signal))
               (setq my-org-sync--process nil)
               (unwind-protect
                   (condition-case err
                       (with-current-buffer (process-buffer process)
                         (goto-char (point-min))
                         (my-org-sync--handle
                          (json-parse-buffer :object-type 'alist :array-type 'list)))
                     (error (my-org-sync--notify (error-message-string err))))
                 (kill-buffer (process-buffer process)))))))))

(defun my-org-sync-now ()
  "Snapshot saved ciphertext, publish it and check for incoming changes."
  (interactive)
  (when my-org-sync--resolution-directory
    (user-error "Finish the active PR resolution before syncing"))
  (unless (file-directory-p (expand-file-name ".git" (my-org-sync--root)))
    (user-error "The Org Git repository has not been initialized"))
  (if my-org-sync--pending
      (condition-case err
          (my-org-sync--apply my-org-sync--pending)
        (error (setq my-org-sync--pending nil)
               (my-org-sync--notify (error-message-string err))))
    (my-org-sync--start "sync")))

(defun my-org-sync--tick ()
  (when (and my-org-sync-mode
             (not (process-live-p my-org-sync--process))
             (not my-org-sync--resolution-directory)
             (file-directory-p (expand-file-name ".git" (my-org-sync--root)))
             (let ((idle (current-idle-time)))
               (and idle (>= (float-time idle) my-org-sync-idle-delay))))
    (condition-case err (my-org-sync-now)
      (error (my-org-sync--notify (error-message-string err))))))

(define-minor-mode my-org-sync-mode
  "Synchronize saved encrypted Org files while Emacs is idle."
  :global t :group 'my-org-sync
  (when (timerp my-org-sync--timer) (cancel-timer my-org-sync--timer))
  (setq my-org-sync--timer nil)
  (if my-org-sync-mode
      (progn
        (add-hook 'find-file-hook #'my-org-sync--protect-buffer)
        (dolist (buffer (my-org-sync--buffers))
          (with-current-buffer buffer (my-org-sync--protect-buffer)))
        (setq my-org-sync--timer (run-at-time 10 my-org-sync-interval #'my-org-sync--tick)))
    (remove-hook 'find-file-hook #'my-org-sync--protect-buffer)))

(defun my-org-sync-resolve-pr (number)
  "Prepare an encrypted worktree for resolving PR NUMBER locally."
  (interactive "nOrg sync PR number: ")
  (setq my-org-sync--resolution-pr number)
  (my-org-sync--start "prepare" (number-to-string number)))

(defun my-org-sync-resume-pr (number)
  "Resume an existing resolution for PR NUMBER."
  (interactive "nOrg sync PR number: ")
  (setq my-org-sync--resolution-pr number)
  (my-org-sync--handle (my-org-sync--call "resolution-status" (number-to-string number))))

(defun my-org-sync--stage-buffer (directory path stage label)
  (let ((buffer (generate-new-buffer (format "*Org conflict %s*" label)))
        (default-directory directory)
        (coding-system-for-read 'no-conversion))
    (with-current-buffer buffer
      (set-buffer-multibyte nil)
      (if (eq 0 (call-process "git" nil t nil "show" (format ":%d:%s" stage path)))
          (let ((plain (epg-decrypt-string (epg-make-context 'OpenPGP) (buffer-string))))
            (erase-buffer) (set-buffer-multibyte t)
            (insert (decode-coding-string plain 'utf-8)))
        (erase-buffer) (set-buffer-multibyte t))
      (org-mode)
      (setq-local backup-inhibited t)
      (setq-local buffer-auto-save-file-name nil)
      (auto-save-mode -1)
      (set-buffer-modified-p nil))
    buffer))

(defun my-org-sync-resolve-file ()
  "Merge one PR conflict in memory using Ediff. Save the result as ciphertext."
  (interactive)
  (unless my-org-sync--resolution-pr (user-error "First prepare or resume a PR"))
  (let* ((status (my-org-sync--call "resolution-status" (number-to-string my-org-sync--resolution-pr)))
         (files (alist-get 'files status))
         (directory (file-name-as-directory (alist-get 'directory status))))
    (unless files (user-error "No unstaged conflicts remain; run my-org-sync-finish-resolution"))
    (let* ((path (completing-read "Conflicted file: " files nil t))
           (base (my-org-sync--stage-buffer directory path 1 "base"))
           (ours (my-org-sync--stage-buffer directory path 2 "device"))
           (theirs (my-org-sync--stage-buffer directory path 3 "main")))
      (setq my-org-sync--resolution-directory directory
            my-org-sync--resolution-path path
            my-org-sync--resolution-sources (list base ours theirs))
      (require 'ediff)
      (ediff-merge-buffers-with-ancestor
       ours theirs base
       (list (lambda ()
               (with-current-buffer ediff-buffer-C
                 (setq buffer-file-name (expand-file-name path directory))
                 (org-mode)
                 (my-org-configure-encryption)
                 (setq-local backup-inhibited t)
                 (auto-save-mode -1))))))))

(defun my-org-sync-stage-resolution ()
  "Save and stage the current encrypted resolution after reviewing its contents."
  (interactive)
  (unless (and my-org-sync--resolution-directory my-org-sync--resolution-path
               (equal buffer-file-name
                      (expand-file-name my-org-sync--resolution-path my-org-sync--resolution-directory)))
    (user-error "Run this in the Ediff merged result buffer"))
  (when (save-excursion
          (goto-char (point-min))
          (re-search-forward "^\\(?:<<<<<<<\\|=======\\|>>>>>>>\\|####### Ancestor\\)" nil t))
    (user-error "Remove conflict markers before staging the result"))
  (save-buffer)
  (let ((default-directory my-org-sync--resolution-directory))
    (unless (eq 0 (call-process "git" nil nil nil "add" "--" my-org-sync--resolution-path))
      (user-error "Could not stage the encrypted result")))
  (message "Encrypted resolution staged; resolve another file or finish the PR"))

(defun my-org-sync-finish-resolution ()
  "Commit and publish a resolved PR branch. The next sync attempts its merge."
  (interactive)
  (unless my-org-sync--resolution-pr (user-error "No resolution is active"))
  (my-org-sync--start "finish" (number-to-string my-org-sync--resolution-pr)))

(defun my-org-sync--refresh-on-command ()
  (when (and my-org-sync-mode my-org-sync--needs-reload)
    (condition-case err (my-org-sync--refresh)
      (error (my-org-sync--notify (error-message-string err))))))
(add-hook 'post-command-hook #'my-org-sync--refresh-on-command)

(defun my-org-sync-delete-resolution ()
  "Resolve a conflicted file by accepting its deletion in the PR worktree."
  (interactive)
  (unless my-org-sync--resolution-pr (user-error "No resolution is active"))
  (let* ((status (my-org-sync--call "resolution-status" (number-to-string my-org-sync--resolution-pr)))
         (path (completing-read "Accept deletion of conflicted file: " (alist-get 'files status) nil t))
         (default-directory (alist-get 'directory status)))
    (unless (eq 0 (call-process "git" nil nil nil "rm" "-f" "--" path))
      (user-error "Could not stage the deletion"))))

(provide 'org-sync)
