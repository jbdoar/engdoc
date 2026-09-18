;;; export_agenda.el --- Project agenda exporter -*- lexical-binding: t; -*-

(require 'org)
(require 'org-agenda)
(require 'subr-x)
(require 'calendar)

(defun engdoc-project-planning-date-range ()
  "Return (START . SPAN) covering all planning dates in current file."
  (let (dates)
    (org-map-entries
     (lambda ()
       (dolist (property '("SCHEDULED" "DEADLINE"))
         (when-let ((value (org-entry-get nil property)))
           (when (string-match
                  "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}"
                  value)
             (push (match-string 0 value) dates)))))
     nil 'file)

    (if dates
        (let* ((sorted (sort dates #'string<))
               (first (car sorted))
               (last (car (last sorted)))
               (span
                (1+ (- (calendar-absolute-from-gregorian
                         (org-date-to-gregorian last))
                       (calendar-absolute-from-gregorian
                         (org-date-to-gregorian first))))))
          (cons first span))
      (cons "0" 1))))

(defun engdoc-project-export-agenda (project-file output)
  "Export the agenda for PROJECT-FILE to OUTPUT."
  (with-current-buffer (find-file-noselect project-file)
    (save-buffer)

    (pcase-let ((`(,start . ,span)
                 (engdoc-project-planning-date-range)))

      (let ((org-agenda-files (list project-file))
            (org-agenda-start-day start)
            (org-agenda-span span)
            (org-agenda-custom-commands
             '(("P" "Project export"
                ((agenda "")
                 (alltodo ""))))))

        (org-agenda nil "P")
        (org-agenda-write output)
        (kill-buffer (current-buffer))))))

(provide 'export_agenda)

;;; export_agenda.el ends here
