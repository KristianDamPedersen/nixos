;;; org-encryption.el --- Encrypted Org files -*- lexical-binding: t; -*-

(require 'epa-file)
(epa-file-enable)

(defconst my-org-encryption-recipients
  ; Recovery key fingerprint
  '("5B68574315AA1860B7C329B3B65B8EB671FAA22F"
  ; Desktop key fingerprint
  "D055A0E9A9FF4D2A7517BC67F99A055334CA4E43")
  "Public keys that can decrypt my Org files.")

(defun my-org-configure-encryption ()
  "Configure recipients and backups for encrypted Org files."
  (when (and buffer-file-name
             (string-suffix-p ".org.gpg" buffer-file-name))
    (setq-local epa-file-encrypt-to my-org-encryption-recipients)
    (setq-local epa-file-select-keys nil)
    (setq-local backup-inhibited t)
    (auto-save-mode -1)))

(add-hook 'org-mode-hook #'my-org-configure-encryption)

(defun my-org-managed-path-p (file)
  "Return non-nil for a local FILE inside my Org directory."
  (and (stringp file)
       (not (file-remote-p file))
       (file-in-directory-p
        (expand-file-name file)
        (expand-file-name org-directory))))

(defun my-org-default-encrypted-file ()
  "Give newly visited Org files an encrypted filename."
  (when (and (my-org-managed-path-p buffer-file-name)
             (string-suffix-p ".org" buffer-file-name)
             (not (file-exists-p buffer-file-name)))
    (let ((encrypted (concat buffer-file-name ".gpg")))
      (when (file-exists-p encrypted)
        (user-error "An encrypted copy exists; open %s" encrypted))
      (set-visited-file-name encrypted t)))
  (when (my-org-managed-path-p buffer-file-name)
    (setq-local backup-inhibited t)
    (auto-save-mode -1))
  (my-org-configure-encryption))

(add-hook 'find-file-hook #'my-org-default-encrypted-file)

(defun my-org-check-write (_start _end filename &rest _args)
  "Require encryption for Org document writes inside my Org directory."
  (when (my-org-managed-path-p filename)
    (cond
     ((string-suffix-p ".org.gpg" filename)
      (setq-local epa-file-encrypt-to my-org-encryption-recipients)
      (setq-local epa-file-select-keys nil))
     ((string-match-p
       "\\.org\\(?:\\.gpg\\)?\\(?:_archive\\)?\\'"
       filename)
      (user-error "Refusing plaintext Org write; use a .org.gpg filename")))))

(advice-add 'write-region :before #'my-org-check-write)
