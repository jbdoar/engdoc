;;; engdoc-acceptance.el --- Acceptance procedure support -*- lexical-binding: t; -*-

;;; Commentary:
;; Validate and export acceptance.org to a controlled PDF and blank XLSX
;; execution template. Completed records are never stored beneath exports/.

;;; Code:

(require 'engdoc)

(defconst engdoc-acceptance-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the acceptance document implementation.")

(defun engdoc-acceptance-export (&optional file)
  "Export acceptance procedure FILE to PDF, TeX, and blank XLSX template."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file
      (user-error "No acceptance file specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file)
      (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_acceptance.py"
                                     engdoc-acceptance-directory))
           (outputs '("acceptance.tex" "acceptance.pdf" "acceptance.xlsx")))
      (engdoc-run-python script (list "--validate" file)
                         "Validating acceptance procedures")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "acceptance")
         (engdoc-run-python
          script
          (list file (expand-file-name "acceptance.xlsx" staging-directory))
          "Exporting blank acceptance execution template")))
      (message "Acceptance procedure export complete: %s" export-directory))))

(provide 'engdoc-acceptance)
;;; engdoc-acceptance.el ends here
