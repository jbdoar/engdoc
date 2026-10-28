;;; engdoc-service.el --- Service and maintenance manual support -*- lexical-binding: t; -*-

(require 'engdoc)

(defconst engdoc-service-directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun engdoc-service-export (&optional file)
  "Export service manual FILE to PDF, TeX, and maintenance XLSX."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file (user-error "No service manual specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file) (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_service.py" engdoc-service-directory))
           (outputs '("service.tex" "service.pdf" "service.xlsx")))
      (engdoc-run-python script (list "--validate" file) "Validating service manual")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "service")
         (engdoc-run-python
          script (list file (expand-file-name "service.xlsx" staging-directory))
          "Exporting maintenance register and blank service records")))
      (message "Service manual export complete: %s" export-directory))))

(provide 'engdoc-service)
;;; engdoc-service.el ends here
