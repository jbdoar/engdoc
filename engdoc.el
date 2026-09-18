;;; engdoc.el --- Engineering documentation and project tooling for Org mode -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, project, org
;; Version: 0.1.0

;;; Commentary:

;; Engineering documentation and project tooling for Emacs Org mode.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'python)

(defgroup engdoc nil
  "Engineering documentation and project tooling."
  :group 'tools)

(defcustom engdoc-python-interpreter nil
  "Python interpreter override for engdoc.
When nil, use `python-shell-interpreter'."
  :type '(choice (const :tag "Use Emacs Python" nil)
                 (file :tag "Python executable"))
  :group 'engdoc)

(defun engdoc-python ()
  "Return the Python interpreter used by engdoc."
  (or engdoc-python-interpreter
      python-shell-interpreter))

(defconst engdoc-directory
  (file-name-directory
   (or load-file-name buffer-file-name))
  "Root directory of the engdoc package.")

(defconst engdoc-documents-directory
  (expand-file-name "documents/" engdoc-directory)
  "Directory containing engdoc document definitions and templates.")

(defvar engdoc-document-types
  '((project
     :filename "project.org"
     :description "Project planning, BOM, schedule, and agenda."
     :template "project/template.org"))
  "Registered engdoc document types.")

(defun engdoc--document-get (type property)
  "Return PROPERTY for document TYPE."
  (plist-get (cdr (assq type engdoc-document-types)) property))

(defun engdoc--document-types ()
  "Return registered document type names."
  (mapcar (lambda (entry)
            (symbol-name (car entry)))
          engdoc-document-types))

(defun engdoc-new-document (type directory)
  "Create an engdoc document of TYPE in DIRECTORY."
  (interactive
   (list
    (intern
     (completing-read
      "Document type: "
      (engdoc--document-types)
      nil t))
    (read-directory-name "Project directory: " default-directory)))

  (let* ((filename (engdoc--document-get type :filename))
         (template (engdoc--document-get type :template))
         (source (expand-file-name template engdoc-documents-directory))
         (destination (expand-file-name filename directory)))

    (when (file-exists-p destination)
      (user-error "%s already exists" destination))

    (unless (file-exists-p source)
      (user-error "Template not found: %s" source))

    (copy-file source destination)

    (find-file destination)))

(defcustom engdoc-project-directories
  '("figs" "datasheets" "purchasing" "exports")
  "Directories created when initializing a project."
  :type '(repeat string)
  :group 'engdoc)

(defun engdoc-init (directory)
  "Initialize an engineering project in DIRECTORY."
  (interactive
   (list (read-directory-name "Project directory: ")))

  (make-directory directory t)

  (dolist (name engdoc-project-directories)
    (make-directory
     (expand-file-name name directory) t))

  (engdoc-new-document 'project directory)

  (message "Initialized project: %s" directory))

(provide 'engdoc)

;;; engdoc.el ends here
