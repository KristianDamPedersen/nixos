;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(setq
 +org-capture-todo-file "todo.org.gpg"
 +org-capture-notes-file "notes.org.gpg"
 +org-capture-journal-file "journal.org.gpg"
 +org-capture-projects-file "projects.org.gpg"
 +org-capture-changelog-file "changelog.org.gpg")

(after! org
  (setq org-default-notes-file
        (expand-file-name "notes.org.gpg" org-directory)
        org-archive-location
        (concat
         (expand-file-name "archive/archive.org.gpg" org-directory)
         "::")))


(load! "org-appetite")
(load! "org-planning")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
;;
(defconst my-emacs-state-directory
  (expand-file-name
   "emacs/"
   (or (getenv "XDG_STATE_HOME")
       (expand-file-name "~/.local/state/"))))

(make-directory my-emacs-state-directory t)
(set-file-modes my-emacs-state-directory #o700)

(setq custom-file
      (expand-file-name "custom.el" my-emacs-state-directory)
      oauth2-auto-plstore
      (expand-file-name "oauth2-auto.plist" my-emacs-state-directory)
      ghostel-module-auto-install nil)

(load custom-file t t)


(after! lean4-mode
  (puthash "workspace/inlayHint/refresh"
           (lambda (_workspace _params) nil)
           (lsp--client-request-handlers
            (gethash 'lean4-lsp lsp-clients))))

(after! notmuch
        (setq sendmail-program
              (expand-file-name "bin/gmail-sync.sh" doom-user-dir)
              message-send-email-function #'message-send-mail-with-sendmail
              message-sendmail-extra-arguments '("send" "--quiet" "-t")
              message-sendmail-f-is-evil t
              notmuch-fcc-dirs nil))

(setq org-gcal-fetch-file-alist
      '(("kristian.dam.pedersen@gmail.com" . "~/org/calendar.org.gpg"))
      org-gcal-down-days 90)

(after! org
  ;; Remove old explicit entries, including saved customizations.
  (dolist (old '("~/org/blocks.org" "~/org/calendar.org"))
    (setq org-agenda-files
          (delete old
                  (delete (expand-file-name old) org-agenda-files))))
  (dolist (file '("~/org/blocks.org.gpg" "~/org/calendar.org.gpg"))
    (add-to-list 'org-agenda-files (expand-file-name file))))

;; Keybindings
(map! :leader
      :desc "Visual week" "o c" #'my-org-calendar-week
      :desc "Month calendar" "o C" #'=calendar)

(map! :after org
      :map org-mode-map
      :localleader
      :desc "Set appetite" "A" #'my-org-appetite-set)

;; Workaround for but in org-gcal clearing timestamp field.
(after! org-gcal
  (defun my-org-gcal-alternate-date-field (str)
    "Return the date field to clear when sending STR."
    (when str
      (if (> (length str) 11) "date" "dateTime")))
  (advice-add 'org-gcal--param-date-alt
              :override #'my-org-gcal-alternate-date-field))

;; 1Password fetch configuration
(use-package! auth-source-1password
  :demand t
  :config
  (setq auth-source-1password-construct-secret-reference
        (lambda (_backend _type host user _port)
          (when (and (equal host "api.github.com")
                     (equal user "KristianDamPedersen^forge"))
            (string-remove-prefix
             "op://"
             "op://Private/Emacs forge/token"))))
  (auth-source-1password-enable))

;; Weekly reservations and Sunday planning.
(after! org
  (load! "org-weekly-blocks"))
(map! :leader :desc "Plan week" "o w" #'my-org-plan-week)

(map! :leader :desc "Reserve time" "o r" #'my-org-calendar-add-reservation)

;; Explicit Google Calendar sync, never triggered by loading this file.
(after! org
  (load! "calendar-credentials")
  (load! "org-google-calendar"))
(map! :leader :desc "Sync Google Calendar" "o s" #'my-org-google-sync)

;; Add project files
(after! org
        (add-to-list 'org-agenda-files
                     (expand-file-name "~/org/projects/")))

;; Gmail sync via SecretSpec controlled credentials
(after! notmuch
  (setq +notmuch-sync-backend
        (shell-quote-argument
         (expand-file-name "bin/gmail-sync.sh" doom-user-dir))))

;; Enable Org files encryption
(load! "org-encryption")
(setq plstore-encrypt-to my-org-encryption-recipients)

;; Sync saved encrypted Org files through device branches and GitHub PRs.
(load! "org-sync")
;; Enable after the new device repository has been configured.
;; (my-org-sync-mode 1)

;; Expand agenda search to include encrypted files
(after! org
  (setq org-agenda-file-regexp
        "\\`[^.].*\\.org\\(\\.gpg\\)?\\'"))

;; Expand file name acceptance to include encrypted files
(after! org
  (defun my-org-refile-to-file (arg file)
    "Refile to an Org file, including an encrypted one."
    (interactive
     (list current-prefix-arg
           (read-file-name
            "Select file to refile to: "
            default-directory nil t nil
            (lambda (file)
              (or (file-directory-p file)
                  (string-match-p
                   "\\.org\\(?:\\.gpg\\)?\\'" file))))))
    (+org/refile-to-current-file arg file))
  (advice-add '+org/refile-to-file
              :override #'my-org-refile-to-file))
