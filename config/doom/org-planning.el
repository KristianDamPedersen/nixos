;;; org-planning.el -*- lexical-binding: t; -*-

(after! org-clock
  (setq org-clock-clocked-in-display 'mode-line
        org-clock-mode-line-total 'current
        org-clock-update-period 1
        org-clock-string-limit 48)

  (defun my-org-clock-display-seconds (text)
    "Show current-session seconds in TEXT without changing Org's clock records."
    (if (and (org-clocking-p)
             (string-match "\\[\\([^]/]+\\)" text))
        (let* ((start (match-beginning 1))
               (end (match-end 1))
               (seconds (max 0 (floor (float-time
                                      (time-subtract (current-time)
                                                     org-clock-start-time)))))
               (elapsed (format "%d:%02d:%02d"
                                (/ seconds 3600)
                                (% (/ seconds 60) 60)
                                (% seconds 60))))
          (set-text-properties 0 (length elapsed)
                               (text-properties-at start text) elapsed)
          (concat (substring text 0 start) elapsed (substring text end)))
      text))

  (advice-add 'org-clock-get-clock-string :filter-return
              #'my-org-clock-display-seconds)
  ;; Apply the display change to a clock already running when this file reloads.
  (when (org-clocking-p)
    (setq org-clock-total-time 0)
    (org-clock-update-mode-line)
    (when (timerp org-clock-mode-line-timer)
      (cancel-timer org-clock-mode-line-timer))
    (setq org-clock-mode-line-timer
          (run-with-timer 1 1 #'org-clock-update-mode-line))))

(after! ghostel
  ;; Doom hides terminal modelines by default, including Org's clock indicator.
  (remove-hook 'ghostel-mode-hook #'mode-line-invisible-mode)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'ghostel-mode)
        (mode-line-invisible-mode -1)))))

(after! org-agenda
  (defun my-org-planning-next-heading ()
    "Return the next heading position without skipping child tasks."
    (save-excursion
      (outline-next-heading)
      (point)))

  (defun my-org-planning-skip-backlog ()
    "Skip tasks that have no explicit priority or already have a plan."
    (when (or (org-entry-get nil "SCHEDULED")
              (member "planned" (org-get-tags nil t))
              (not (string-match-p "\\[#[ABC]\\]" (org-get-heading t t))))
      (my-org-planning-next-heading)))

  (defun my-org-planning-skip-non-task ()
    "Only show unfinished TODO entries in the deadline block."
    (unless (member (org-get-todo-state) org-not-done-keywords)
      (my-org-planning-next-heading)))

  (setq org-agenda-custom-commands
        (cons
         '("b" "Deadlines, appetite and prioritized backlog"
           ((agenda ""
                    ((org-agenda-overriding-header
                      "Approaching deadlines and overdue tasks")
                     (org-agenda-span 1)
                     (org-agenda-start-day "+0d")
                     (org-agenda-start-on-weekday nil)
                     (org-agenda-entry-types '(:deadline))
                     (org-deadline-warning-days 7)
                     (org-agenda-skip-deadline-if-done t)
                     (org-agenda-skip-deadline-prewarning-if-scheduled nil)
                     (org-agenda-skip-function #'my-org-planning-skip-non-task)
                     (org-agenda-sorting-strategy '(deadline-up priority-down))))
            (tags "LEVEL>0"
                  ((org-agenda-overriding-header "Appetite needs attention")
                   (org-agenda-prefix-format
                    " %(my-org-appetite-agenda-summary) ")
                   (org-agenda-skip-function #'my-org-appetite-skip-unflagged)))
            (todo "TODO"
                  ((org-agenda-overriding-header
                    "Prioritized tasks needing time")
                   (org-agenda-sorting-strategy '(priority-down category-keep))
                   (org-agenda-skip-function #'my-org-planning-skip-backlog)))))
         (assoc-delete-all "b" org-agenda-custom-commands))))
