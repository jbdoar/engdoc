;;; engdoc-user-manual.el --- Controlled user-manual support -*- lexical-binding: t; -*-

(require 'engdoc)

(defconst engdoc-user-manual-directory
  (file-name-directory (or load-file-name buffer-file-name)))

(defun engdoc-user-manual-export (&optional file)
  "Export user manual FILE to PDF, HTML, TeX, and content-register XLSX."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file (user-error "No user manual specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file) (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_user_manual.py"
                                     engdoc-user-manual-directory))
           (outputs '("user-manual.tex" "user-manual.pdf" "user-manual.html"
                      "user-manual.xlsx")))
      (engdoc-run-python script (list "--validate" file) "Validating user manual")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "user-manual")
         (engdoc-export-org-html
          file (expand-file-name "user-manual.html" staging-directory))
         (engdoc-run-python
          script (list file (expand-file-name "user-manual.xlsx" staging-directory))
          "Exporting user content register")))
      (message "User manual export complete: %s" export-directory))))

(provide 'engdoc-user-manual)
;;; engdoc-user-manual.el ends here
