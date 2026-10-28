;;; engdoc-risk.el --- Risk and hazard analysis support -*- lexical-binding: t; -*-

(require 'engdoc)

(defconst engdoc-risk-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the risk document implementation.")

(defun engdoc-risk-export (&optional file)
  "Export risk and hazard analysis FILE to PDF, TeX, and XLSX."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file (user-error "No risk file specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file) (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_risk.py" engdoc-risk-directory))
           (outputs '("risk.tex" "risk.pdf" "risk.xlsx")))
      (engdoc-run-python script (list "--validate" file)
                         "Validating risk and hazard analysis")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "risk")
         (engdoc-run-python
          script (list file (expand-file-name "risk.xlsx" staging-directory))
          "Exporting hazard register")))
      (message "Risk and hazard export complete: %s" export-directory))))

(provide 'engdoc-risk)
;;; engdoc-risk.el ends here
