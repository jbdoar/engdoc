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
  '(
    (project
     :filename "project.org"
     :description "Project planning, BOM, schedule, and agenda."
     :template "project/template.org"
     :module "engdoc-project"
     :exporter engdoc-project-export)
    (requirements
     :filename "requirements.org"
     :description "System requirements specification"
     :template "requirements/template.org"
     :module "engdoc-requirements"
     :exporter engdoc-requirements-export)
    )
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

(defun engdoc-export (&optional directory)
  "Export all registered documents found in DIRECTORY."
  (interactive
   (list (read-directory-name
          "Export documents in directory: "
          default-directory)))

  (let ((directory (file-name-as-directory
                    (expand-file-name
                     (or directory default-directory))))
        (exported nil)
        (failed nil))

    (dolist (entry engdoc-document-types)
      (let* ((type (car entry))
             (filename (plist-get (cdr entry) :filename))
             (module (plist-get (cdr entry) :module))
             (exporter (plist-get (cdr entry) :exporter))
             (file (expand-file-name filename directory)))

        (when (file-exists-p file)
          (condition-case err
              (progn
                (when module
                  (let ((load-path
                         (cons
                          (expand-file-name
                           (format "documents/%s" type)
                           engdoc-directory)
                          load-path)))
                    (require (intern module))))

                (unless (and exporter (fboundp exporter))
                  (error "Exporter unavailable: %s" exporter))

                (funcall exporter file)
                (push type exported))

            (error
             (push (cons type (error-message-string err))
                   failed))))))

    (setq exported (nreverse exported)
          failed (nreverse failed))

    (if failed
        (progn
          (dolist (failure failed)
            (message "Export failed [%s]: %s"
                     (car failure)
                     (cdr failure)))
          (user-error
           "Exported %d document(s); %d failed. See *Messages*"
           (length exported)
           (length failed)))
      (message "Exported %d document(s): %s"
               (length exported)
               (if exported
                   (mapconcat #'symbol-name exported ", ")
                 "none found")))))

(add-to-list 'load-path
             (expand-file-name "documents/project" engdoc-directory))


(defun engdoc-export-directory (file)
  "Return the exports directory for FILE, creating it if necessary."
  (let ((directory
         (expand-file-name
          "exports"
          (file-name-directory (expand-file-name file)))))
    (make-directory directory t)
    directory))


(provide 'engdoc)

;;; engdoc.el ends here
