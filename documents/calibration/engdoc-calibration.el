;;; engdoc-calibration.el --- Calibration program support -*- lexical-binding: t; -*-

(require 'engdoc)

(defconst engdoc-calibration-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the calibration document implementation.")

(defun engdoc-calibration-export (&optional file)
  "Export calibration program FILE to PDF, TeX, and blank XLSX template."
  (interactive)
  (let ((file (or file buffer-file-name)))
    (unless file (user-error "No calibration file specified"))
    (setq file (expand-file-name file))
    (with-current-buffer (find-file-noselect file) (save-buffer))
    (let* ((export-directory (engdoc-export-directory file))
           (script (expand-file-name "export_calibration.py"
                                     engdoc-calibration-directory))
           (outputs '("calibration.tex" "calibration.pdf" "calibration.xlsx")))
      (engdoc-run-python script (list "--validate" file)
                         "Validating calibration program")
      (engdoc-with-export-transaction
       export-directory outputs
       (lambda (staging-directory)
         (engdoc-export-org-pdf file staging-directory "calibration")
         (engdoc-run-python
          script
          (list file (expand-file-name "calibration.xlsx" staging-directory))
          "Exporting blank calibration execution template")))
      (message "Calibration export complete: %s" export-directory))))

(provide 'engdoc-calibration)
;;; engdoc-calibration.el ends here
