;;; engdoc-project.el --- Project document support -*- lexical-binding: t; -*-

;;; Commentary:
;; Export project.org to BOM, schedule, and agenda outputs.

;;; Code:
(add-to-list 'load-path
             (file-name-directory
              (or load-file-name buffer-file-name)))

(require 'engdoc)
(require 'export_agenda)
(require 'export_html)

(defconst engdoc-project-directory
  (file-name-directory
   (or load-file-name buffer-file-name))
  "Directory containing the project document implementation.")

(defun engdoc-project--run-python (python script input output)
  "Run SCRIPT with INPUT and OUTPUT, raising an error on failure."
  (let ((log-buffer (get-buffer-create "*engdoc-export*")))
    (with-current-buffer log-buffer
      (goto-char (point-max))
      (insert (format "\nRunning %s\n" script)))

    (let ((status
           (process-file python nil log-buffer nil
                         script input output)))

      (unless (and (integerp status) (zerop status))
        (display-buffer log-buffer)
        (error "Export failed: %s (exit status %s); see *engdoc-export*"
               (file-name-nondirectory script)
               status)))))


(defun engdoc-project-export (&optional file)
  "Export project HTML, BOM, schedule, and agenda for FILE."
  (interactive)

  (let ((file (or file buffer-file-name)))
    (unless file
      (user-error "No project file specified"))

    (with-current-buffer (find-file-noselect file)
      (save-buffer))

    (let* ((python (engdoc-python))
           (project-file (expand-file-name file))
           (project-dir (file-name-directory project-file))
           (export-dir (engdoc-export-directory project-file))

           (bom-script
            (expand-file-name "export_bom.py"
                              engdoc-project-directory))

           (schedule-script
            (expand-file-name "export_schedule.py"
                              engdoc-project-directory))

           (bom-output
            (expand-file-name "bom.xlsx" export-dir))

           (schedule-output
            (expand-file-name "schedule.xlsx" export-dir))

           (agenda-output
            (expand-file-name "agenda.html" export-dir))

           (html-output
            (expand-file-name "project.html" export-dir)))

      (let ((default-directory project-dir))

        ;; Org exports
        (engdoc-project-export-agenda
         project-file agenda-output)

        (engdoc-project-export-html
         project-file html-output)

        ;; Python exports: synchronous and failure-aware
        (engdoc-project--run-python
         python bom-script project-file bom-output)

        (engdoc-project--run-python
         python schedule-script project-file schedule-output))

      ;; Verify that all expected files exist.
      (dolist (output (list bom-output
                            schedule-output
                            agenda-output
                            html-output))
        (unless (file-exists-p output)
          (error "Expected export missing: %s" output)))

      (message "Project export complete: %s" export-dir))))

(provide 'engdoc-project)

;;; engdoc-project.el ends here
