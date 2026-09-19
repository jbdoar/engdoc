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
           (tex-file (expand-file-name "requirements.tex" export-dir))
           (pdf-file (expand-file-name "requirements.pdf" export-dir))
           (xlsx-file (expand-file-name "requirements.xlsx" export-dir))
	   (fat-file (expand-file-name "fat.xlsx" export-dir))
	   (sat-file (expand-file-name "sat.xlsx" export-dir))
	   (checklist-script
	    (expand-file-name
	     "export_checklists.py"
	     engdoc-requirements-directory))

           (script (expand-file-name
                    "export_requirements.py"
                    engdoc-requirements-directory))
           (python (engdoc-python))
           (log-buffer (get-buffer-create "*engdoc-export*")))

      (unless (file-exists-p checklist-script)
	(error "Checklist exporter missing: %s" checklist-script))
      
      ;; Save the source before validation.
      (with-current-buffer (find-file-noselect file)
	(save-buffer))

      ;; Validate before generating any artifacts.
      (with-current-buffer log-buffer
	(goto-char (point-max))
	(insert "\nValidating requirements\n"))

      (let ((status
	     (process-file python nil log-buffer nil
			   script "--validate" file)))

	(with-current-buffer log-buffer
	  (goto-char (point-max))
	  (insert (format "Input file: %s\n" file)))

	(unless (and (integerp status) (zerop status))
	  (display-buffer log-buffer)
	  (error
	   "Requirements validation failed (status %s); see *engdoc-export*"
	   status)))
      
      ;; Generate LaTeX.
      (with-current-buffer (find-file-noselect file)
        (org-export-to-file 'latex tex-file))

      ;; Compile PDF.
      (let ((default-directory export-dir))
        (org-latex-compile tex-file))

      (unless (file-exists-p pdf-file)
        (error "Requirements PDF missing: %s" pdf-file))

      ;; Generate XLSX synchronously.
      (with-current-buffer log-buffer
        (goto-char (point-max))
        (insert "\nExporting requirements register\n"))

      (let ((status
             (process-file python nil log-buffer nil
                           script file xlsx-file)))

        (unless (and (integerp status) (zerop status))
          (display-buffer log-buffer)
          (error
           "Requirements XLSX export failed (status %s); see *engdoc-export*"
           status)))

      (unless (file-exists-p xlsx-file)
        (error "Requirements XLSX missing: %s" xlsx-file))

      ;; Generate FAT and SAT checklists.
      (with-current-buffer log-buffer
	(goto-char (point-max))
	(insert "\nExporting FAT/SAT checklists\n"))

      (let ((status
	     (process-file python nil log-buffer nil
			   checklist-script file export-dir)))
	(unless (and (integerp status) (zerop status))
	  (display-buffer log-buffer)
	  (error
	   "Checklist export failed (status %s); see *engdoc-export*"
	   status)))

      (dolist (output (list fat-file sat-file))
	(unless (file-exists-p output)
	  (error "Expected checklist missing: %s" output)))
      
      (message "Requirements export complete: %s" export-dir))))

(provide 'engdoc-requirements)

;;; engdoc-requirements.el ends here
