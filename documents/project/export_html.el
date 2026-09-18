;;; export_html.el --- Project HTML exporter -*- lexical-binding: t; -*-

;;; Commentary:
;; Export the complete project document to HTML.

;;; Code:

(require 'org)
(require 'ox-html)

(defun engdoc-project-export-html (project-file output)
  "Export PROJECT-FILE as HTML to OUTPUT."
  (with-current-buffer (find-file-noselect project-file)
    (save-buffer)

    (let ((org-export-with-toc t)
          (org-export-with-section-numbers t)
          (org-html-validation-link nil))

      (org-export-to-file
       'html
       output
       nil nil nil nil
       '(:with-toc t)))))

(provide 'export_html)

;;; export_html.el ends here
