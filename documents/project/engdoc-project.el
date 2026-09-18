;;; engdoc-project.el --- Project document support -*- lexical-binding: t; -*-

;;; Commentary:
;; Export project.org to BOM, schedule, and agenda outputs.

;;; Code:


(add-to-list 'load-path
             (file-name-directory
              (or load-file-name buffer-file-name)))

(require 'compile)
(require 'subr-x)
(require 'engdoc)
(require 'export_agenda)
(require 'export_html)

(defconst engdoc-project-directory
  (file-name-directory
   (or load-file-name buffer-file-name))
  "Directory containing the project document implementation.")

(defun engdoc-project-export ()
  "Export project HTML, BOM xlsx, schedule xlsx, and agenda HTML for the current project."
  (interactive)

  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))

  (save-buffer)

  (let* ((python (engdoc-python))
	 (project-file buffer-file-name)
         (project-dir (file-name-directory project-file))

         (bom-script
          (expand-file-name "export_bom.py"
                            engdoc-project-directory))

         (schedule-script
          (expand-file-name "export_schedule.py"
                            engdoc-project-directory))

         (bom-output
          (expand-file-name "bom.xlsx" project-dir))

         (schedule-output
          (expand-file-name "schedule.xlsx" project-dir))

         (agenda-output
          (expand-file-name "agenda.html" project-dir))

	 (html-output
	  (expand-file-name "project.html" project-dir)))

    ;; Export agenda.
    (engdoc-project-export-agenda
     project-file agenda-output)

    ;; Export complete project document.
    (engdoc-project-export-html
     project-file html-output)


    ;; Export BOM and schedule.
    (compile
     (string-join
      (list
       (shell-quote-argument python)
       (shell-quote-argument bom-script)
       (shell-quote-argument project-file)
       (shell-quote-argument bom-output)

       "&&"

       (shell-quote-argument python)
       (shell-quote-argument schedule-script)
       (shell-quote-argument project-file)
       (shell-quote-argument schedule-output))
      " "))))

(provide 'engdoc-project)

;;; engdoc-project.el ends here
