;;; engdoc-design.el --- Engineering design document support -*- lexical-binding: t; -*-

;;; Commentary:
;; Validate and export design.org to PDF, TeX, and an XLSX design register.

;;; Code:

(require 'engdoc)

(defconst engdoc-design-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the design document implementation.")

(defun engdoc-design-export (&optional file)
  "Export engineering design FILE to PDF, TeX, and XLSX."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file
      (user-error "No design file specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file)
      (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_design.py"
                                     engdoc-design-directory))
           (outputs '("design.tex" "design.pdf" "design.xlsx")))
      (engdoc-run-python script (list "--validate" file)
                         "Validating engineering design")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "design")
         (engdoc-run-python
          script
          (list file (expand-file-name "design.xlsx" staging-directory))
          "Exporting design register")))
      (message "Engineering design export complete: %s" export-directory))))

(provide 'engdoc-design)
;;; engdoc-design.el ends here
