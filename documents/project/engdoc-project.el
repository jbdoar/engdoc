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

(defun engdoc-project-export (&optional file)
  "Export project HTML, BOM, schedule, and agenda for FILE."
  (interactive)

  (let ((file (or file buffer-file-name)))
    (unless file
      (user-error "No project file specified"))

    (with-current-buffer (find-file-noselect file)
      (save-buffer))

    (let* ((project-file (expand-file-name file))
           (project-dir (file-name-directory project-file))
           (export-dir (engdoc-export-directory project-file))
           (bom-format (engdoc-read-keyword project-file
                                             "ENGDOC_BOM_FORMAT" "default"))

           (validator-script
            (expand-file-name "validate_project.py"
                              engdoc-project-directory))

           (bom-script
            (expand-file-name "export_bom.py"
                              engdoc-project-directory))

           (schedule-script
            (expand-file-name "export_schedule.py"
                              engdoc-project-directory))

           (outputs '("bom.xlsx" "schedule.xlsx"
                      "agenda.html" "project.html")))

      ;; Validation happens before the transaction creates any artifacts.
      (engdoc-run-python validator-script (list project-file)
                         "Validating project")

      (engdoc-with-export-transaction
       export-dir outputs
       (lambda (staging-directory)
         (let ((default-directory project-dir)
               (bom-output (expand-file-name "bom.xlsx" staging-directory))
               (schedule-output
                (expand-file-name "schedule.xlsx" staging-directory))
               (agenda-output
                (expand-file-name "agenda.html" staging-directory))
               (html-output
                (expand-file-name "project.html" staging-directory)))
           (engdoc-project-export-agenda project-file agenda-output)
           (engdoc-project-export-html project-file html-output)
           (engdoc-run-python
            bom-script
            (append (engdoc-format-arguments project-file "BOM" bom-format)
                    (list project-file bom-output))
            (format "Exporting BOM (%s format)" bom-format))
           (engdoc-run-python
            schedule-script (list project-file schedule-output)
            "Exporting schedule"))))

      (message "Project export complete: %s" export-dir))))

(provide 'engdoc-project)

;;; engdoc-project.el ends here
