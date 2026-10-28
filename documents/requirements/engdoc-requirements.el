;;; engdoc-requirements.el --- Requirements support -*- lexical-binding: t; -*-

(require 'engdoc)
(require 'ox-latex)

(defconst engdoc-requirements-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the requirements exporter.")

(defun engdoc-requirements-export (&optional file)
  "Export requirements FILE to PDF, XLSX and FAT/SAT checklists."
  (interactive)

  (let ((file (or file buffer-file-name)))
    (unless file
      (user-error "No requirements file specified"))

    (setq file (expand-file-name file))

    (let* ((export-dir (engdoc-export-directory file))
	   (outputs '("requirements.tex" "requirements.pdf"
	              "requirements.xlsx" "fat.xlsx" "sat.xlsx"))
	   (checklist-script
	    (expand-file-name
	     "export_checklists.py"
	     engdoc-requirements-directory))

           (script (expand-file-name
                    "export_requirements.py"
                    engdoc-requirements-directory)))

      (unless (file-exists-p checklist-script)
	(error "Checklist exporter missing: %s" checklist-script))
      
      ;; Save the source before validation.
      (with-current-buffer (find-file-noselect file)
	(save-buffer))

      ;; Validate before generating any artifacts.
      (engdoc-run-python script (list "--validate" file)
                         "Validating requirements")

      (engdoc-with-export-transaction
       export-dir outputs
       (lambda (staging-directory)
         (let ((xlsx-file
                (expand-file-name "requirements.xlsx" staging-directory)))
           ;; Org and LaTeX outputs.
           (engdoc-export-org-pdf file staging-directory "requirements")

           ;; Spreadsheet outputs.
           (engdoc-run-python script (list file xlsx-file)
                              "Exporting requirements register")
           (engdoc-run-python checklist-script
                              (list file staging-directory)
                              "Exporting FAT/SAT checklists"))))
      
      (message "Requirements export complete: %s" export-dir))))

(provide 'engdoc-requirements)

;;; engdoc-requirements.el ends here
