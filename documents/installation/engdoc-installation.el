;;; engdoc-installation.el --- Installation and commissioning support -*- lexical-binding: t; -*-

(require 'engdoc)

(defconst engdoc-installation-directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun engdoc-installation-export (&optional file)
  "Export installation and commissioning FILE to PDF, TeX, and blank XLSX."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file (user-error "No installation file specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file) (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_installation.py"
                                     engdoc-installation-directory))
           (outputs '("installation.tex" "installation.pdf" "installation.xlsx")))
      (engdoc-run-python script (list "--validate" file)
                         "Validating installation and commissioning plan")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "installation")
         (engdoc-run-python
          script (list file (expand-file-name "installation.xlsx" staging-directory))
          "Exporting blank site execution template")))
      (message "Installation and commissioning export complete: %s"
               export-directory))))

(provide 'engdoc-installation)
;;; engdoc-installation.el ends here
