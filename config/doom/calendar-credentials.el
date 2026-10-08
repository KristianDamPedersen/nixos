;;; calendar-credentials.el --- Calendar credentials -*- lexical-binding: t; -*-

(require 'json)

(defvar my-google-calendar-credentials-loaded nil)

(defun my-google-calendar-ensure-credentials ()
  "Load the Google OAuth client from SecretSpec once per Emacs session."
  (unless my-google-calendar-credentials-loaded
    (unless (executable-find "secretspec")
      (user-error "Emacs cannot find the secretspec executable"))
    (let* ((default-directory doom-user-dir)
           (manifest (expand-file-name "secretspec.toml" doom-user-dir))
           (credentials
            (with-temp-buffer
              (let ((status
                     (process-file
                      "secretspec" nil (list (current-buffer) nil) nil
                      "--file" manifest
                      "get" "GOOGLE_CALENDAR_CLIENT_CREDENTIALS"
                      "--profile" "default"
                      "--provider" "onepassword://Private")))
                (unless (equal status 0)
                  (user-error
                   "SecretSpec failed; check 1Password access and the manifest")))
              (goto-char (point-min))
              (condition-case nil
                  (json-parse-buffer :object-type 'alist)
                (error
                 (user-error "SecretSpec returned invalid calendar client JSON")))))
           (client (alist-get 'installed credentials))
           (client-id (alist-get 'client_id client))
           (client-secret (alist-get 'client_secret client)))
      (unless (and (stringp client-id)
                   (> (length client-id) 0)
                   (stringp client-secret)
                   (> (length client-secret) 0))
        (user-error "Calendar client JSON needs installed.client_id and client_secret"))
      (setq org-gcal-client-id client-id
            org-gcal-client-secret client-secret)
      ;; Supply credentials before loading org-gcal.
      (require 'org-gcal)
      ;; Also update its provider if the package was already loaded.
      (org-gcal-reload-client-id-secret)
      (setq my-google-calendar-credentials-loaded t)))
  nil)

(provide 'calendar-credentials)
