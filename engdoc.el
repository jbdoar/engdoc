;;; engdoc.el --- Engineering documentation and project tooling for Org mode -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "29.1"))
;; Keywords: tools, project, org
;; Version: 0.1.0

;;; Commentary:

;; Engineering documentation and project tooling for Emacs Org mode.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'ox)
(require 'python)
(require 'seq)
(require 'json)

(defvar org-latex-compiler)

(defgroup engdoc nil
  "Engineering documentation and project tooling."
  :group 'tools)

(defcustom engdoc-python-interpreter nil
  "Python interpreter override for engdoc.
When nil, use `python-shell-interpreter'."
  :type '(choice (const :tag "Use Emacs Python" nil)
                 (file :tag "Python executable"))
  :group 'engdoc)

(defcustom engdoc-profile-directories
  (list (expand-file-name "profiles" (file-name-directory
                                      (or load-file-name buffer-file-name))))
  "Directories containing named engdoc presentation profiles.
Each profile is a directory containing profile.json.  A project's
.engdoc/profiles directory is searched before these directories."
  :type '(repeat directory)
  :group 'engdoc)

(defcustom engdoc-format-directories
  (list (expand-file-name "formats" (file-name-directory
                                     (or load-file-name buffer-file-name))))
  "Directories containing external artifact format adapters.
A project's .engdoc/formats directory is searched before these directories."
  :type '(repeat directory)
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

(defconst engdoc-metadata-fields
  '(("TITLE" . "Title")
    ("ENGDOC_PROJECT_NAME" . "Project Name")
    ("ENGDOC_PROJECT_ID" . "Project ID")
    ("ENGDOC_DOCUMENT_ID" . "Document ID")
    ("ENGDOC_REVISION" . "Revision")
    ("ENGDOC_STATUS" . "Status")
    ("AUTHOR" . "Author / Owner")
    ("ENGDOC_ISSUE_DATE" . "Issue Date")
    ("ENGDOC_RELATED_DOCUMENTS" . "Related Documents"))
  "Org keywords used as the shared engdoc metadata schema.")

(defvar engdoc--export-metadata nil
  "Dynamically bound metadata inserted into an Org export copy.")

(defvar engdoc--export-latex-header nil
  "Dynamically bound profile header inserted into a LaTeX export copy.")

(defun engdoc-insert-profile-latex-header (backend)
  "Insert the selected profile header when BACKEND is LaTeX-derived."
  (when (and engdoc--export-latex-header
             (org-export-derived-backend-p backend 'latex))
    (goto-char (point-min))
    (insert "#+LATEX_HEADER: " engdoc--export-latex-header "\n")))

(defun engdoc-read-keyword (file keyword &optional default)
  "Read Org KEYWORD from FILE, returning DEFAULT when it is absent or empty."
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((case-fold-search t))
      (if (re-search-forward
           (format "^#\\+%s:[ \t]*\\(.*?\\)[ \t]*$" (regexp-quote keyword))
           nil t)
          (let ((value (string-trim (match-string-no-properties 1))))
            (if (string-empty-p value) default value))
        default))))

(defun engdoc--named-resource-directory (file category name roots marker)
  "Resolve named resource NAME for CATEGORY relative to FILE and ROOTS.
MARKER must exist in the selected directory."
  (unless (string-match-p "\\`[A-Za-z0-9][A-Za-z0-9._-]*\\'" name)
    (error "Invalid engdoc %s name: %s" category name))
  (let* ((project-root (file-name-directory (expand-file-name file)))
         (search-roots (cons (expand-file-name
                              (format ".engdoc/%s" category) project-root)
                             roots))
         (directory
          (seq-find
           (lambda (root)
             (file-exists-p (expand-file-name marker
                                               (expand-file-name name root))))
           search-roots)))
    (unless directory
      (error "Unknown engdoc %s: %s" category name))
    (expand-file-name name directory)))

(defun engdoc-profile (file)
  "Return the resolved presentation profile for FILE."
  (let* ((name (engdoc-read-keyword file "ENGDOC_PROFILE" "default"))
         (directory (engdoc--named-resource-directory
                     file "profiles" name engdoc-profile-directories
                     "profile.json")))
    (list :name name :directory directory)))

(defun engdoc--profile-data (file)
  "Return FILE's resolved profile together with its parsed manifest."
  (let* ((profile (engdoc-profile file))
         (manifest (expand-file-name "profile.json"
                                     (plist-get profile :directory)))
         (data (with-temp-buffer
                 (insert-file-contents manifest)
                 (json-parse-buffer :object-type 'alist
                                    :array-type 'list))))
    (plist-put profile :data data)))

(defun engdoc--latex-command-value (value)
  "Escape a controlled metadata VALUE for a simple LaTeX command argument."
  (let ((value (or value "")))
    (dolist (replacement '(("\\" . "\\textbackslash{}")
                           ("{" . "\\{") ("}" . "\\}")
                           ("#" . "\\#") ("$" . "\\$")
                           ("%" . "\\%") ("&" . "\\&")
                           ("_" . "\\_") ("^" . "\\^{}")
                           ("~" . "\\~{}")) value)
      (setq value (replace-regexp-in-string
                   (regexp-quote (car replacement)) (cdr replacement)
                   value t t)))))

(defun engdoc--profile-latex-header (file)
  "Return the LaTeX header configured by FILE's presentation profile."
  (let* ((profile (engdoc--profile-data file))
         (directory (plist-get profile :directory))
         (data (plist-get profile :data))
         (relative (alist-get 'latex_header data))
         (commands (alist-get 'latex_metadata_commands data))
         lines)
    (when relative
      (let ((header (expand-file-name relative directory)))
        (unless (file-regular-p header)
          (error "Profile LaTeX header does not exist: %s" header))
        (push (format "\\input{%s}" header) lines)))
    (dolist (mapping commands)
      (let* ((keyword (symbol-name (car mapping)))
             (command (cdr mapping))
             (value (engdoc-read-keyword file keyword "")))
        (unless (string-empty-p value)
          (push (format "\\%s{%s}" command
                        (engdoc--latex-command-value value)) lines))))
    (string-join (nreverse lines) "\n")))

(defun engdoc--profile-compiler (file)
  "Return the LaTeX compiler selected by FILE's profile."
  (or (alist-get 'latex_compiler
                 (plist-get (engdoc--profile-data file) :data))
      org-latex-compiler))

(defun engdoc--profile-process-environment (file)
  "Return a process environment with FILE's profile TeX paths applied."
  (let* ((profile (engdoc--profile-data file))
         (directory (plist-get profile :directory))
         (paths (alist-get 'texinputs (plist-get profile :data)))
         (resolved (mapcar (lambda (path) (expand-file-name path directory)) paths))
         (existing (or (getenv "TEXINPUTS") ""))
         (value (string-join (append resolved (list existing))
                             (if (characterp path-separator)
                                 (char-to-string path-separator)
                               path-separator))))
    (cons (concat "TEXINPUTS=" value) process-environment)))

(defun engdoc-format-arguments (file format-kind format-name)
  "Return CLI arguments resolving FORMAT-KIND and FORMAT-NAME for FILE."
  (unless (string-match-p "\\`[A-Za-z0-9][A-Za-z0-9._-]*\\'" format-name)
    (error "Invalid engdoc %s format name: %s" format-kind format-name))
  (let ((project-root (file-name-directory (expand-file-name file))))
    (append (list "--format" format-name)
            (cl-mapcan
             (lambda (directory) (list "--format-directory" directory))
             (cons (expand-file-name ".engdoc/formats" project-root)
                   engdoc-format-directories)))))

(defun engdoc-read-metadata (file)
  "Return shared document metadata keywords read from Org FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let (metadata)
      (dolist (field engdoc-metadata-fields (nreverse metadata))
        (goto-char (point-min))
        (let ((regexp (format "^#\\+%s:[ \t]*\\(.*?\\)[ \t]*$"
                              (regexp-quote (car field)))))
          (push (cons (car field)
                      (if (re-search-forward regexp nil t)
                          (match-string-no-properties 1)
                        ""))
                metadata))))))

(defun engdoc--org-table-value (value)
  "Make VALUE safe for use in a simple Org table cell."
  (replace-regexp-in-string "|" "\\vert{}" (or value "") t t))

(defun engdoc-insert-export-metadata (_backend)
  "Insert document-control metadata into an Org export copy."
  (when engdoc--export-metadata
    (goto-char (point-min))
    (when (re-search-forward org-heading-regexp nil t)
      (beginning-of-line)
      (insert "Document control:\n\n| Field | Value |\n|---+---|\n")
      (dolist (field engdoc-metadata-fields)
        (let ((value (cdr (assoc (car field) engdoc--export-metadata))))
          (when (and value (not (string-empty-p value)))
            (insert (format "| %s | %s |\n"
                            (cdr field) (engdoc--org-table-value value)))))
      (insert "\n")))))

(defun engdoc-export-org-pdf (file staging-directory basename)
  "Export Org FILE to BASENAME.tex and BASENAME.pdf in STAGING-DIRECTORY.
Return a list containing the absolute TeX and PDF filenames."
  (require 'ox-latex)
  (let* ((tex-file (expand-file-name (concat basename ".tex")
                                     staging-directory))
         (pdf-file (expand-file-name (concat basename ".pdf")
                                     staging-directory))
         (engdoc--export-metadata (engdoc-read-metadata file))
         (engdoc--export-latex-header (engdoc--profile-latex-header file))
         (org-latex-compiler (engdoc--profile-compiler file))
         (process-environment (engdoc--profile-process-environment file))
         (org-export-before-processing-functions
          (append (list #'engdoc-insert-profile-latex-header
                        #'engdoc-insert-export-metadata)
                  org-export-before-processing-functions)))
    (with-current-buffer (find-file-noselect file)
      (org-export-to-file 'latex tex-file))
    (let ((default-directory staging-directory))
      (org-latex-compile tex-file))
    (engdoc-verify-outputs (list tex-file pdf-file))
    (list tex-file pdf-file)))

(defun engdoc-export-org-html (file output)
  "Export Org FILE to standalone HTML OUTPUT with document metadata."
  (require 'ox-html)
  (let ((engdoc--export-metadata (engdoc-read-metadata file))
        (org-export-before-processing-functions
         (cons #'engdoc-insert-export-metadata
               org-export-before-processing-functions))
        (org-export-with-toc t)
        (org-export-with-section-numbers t)
        (org-html-htmlize-output-type nil)
        (org-html-validation-link nil))
    (with-current-buffer (find-file-noselect file)
      (org-export-to-file 'html output nil nil nil nil '(:with-toc t)))
    (engdoc-verify-outputs (list output))
    output))

(defvar engdoc-document-types
  '(
    (project
     :filename "project.org"
     :description "Project planning, BOM, schedule, and agenda."
     :template "project/template.org"
     :module "engdoc-project"
     :exporter engdoc-project-export
     :outputs ("bom.xlsx" "schedule.xlsx" "agenda.html" "project.html")
     :python-dependencies ("openpyxl"))
    (requirements
     :filename "requirements.org"
     :description "System requirements specification"
     :template "requirements/template.org"
     :module "engdoc-requirements"
     :exporter engdoc-requirements-export
     :outputs ("requirements.tex" "requirements.pdf" "requirements.xlsx"
               "fat.xlsx" "sat.xlsx")
     :python-dependencies ("openpyxl"))
    (design
     :filename "design.org"
     :description "Engineering design description and design register."
     :template "design/template.org"
     :module "engdoc-design"
     :exporter engdoc-design-export
     :outputs ("design.tex" "design.pdf" "design.xlsx")
     :python-dependencies ("openpyxl"))
    (acceptance
     :filename "acceptance.org"
     :description "Acceptance procedures and blank execution templates."
     :template "acceptance/template.org"
     :module "engdoc-acceptance"
     :exporter engdoc-acceptance-export
     :outputs ("acceptance.tex" "acceptance.pdf" "acceptance.xlsx")
     :python-dependencies ("openpyxl"))
    (calibration
     :filename "calibration.org"
     :description "Calibration program, equipment register, and blank records."
     :template "calibration/template.org"
     :module "engdoc-calibration"
     :exporter engdoc-calibration-export
     :outputs ("calibration.tex" "calibration.pdf" "calibration.xlsx")
     :python-dependencies ("openpyxl"))
    (risk
     :filename "risk.org"
     :description "Risk and hazard analysis with mitigation traceability."
     :template "risk/template.org"
     :module "engdoc-risk"
     :exporter engdoc-risk-export
     :outputs ("risk.tex" "risk.pdf" "risk.xlsx")
     :python-dependencies ("openpyxl"))
    (installation
     :filename "installation.org"
     :description "Installation, commissioning, punch-list, and handover plan."
     :template "installation/template.org"
     :module "engdoc-installation"
     :exporter engdoc-installation-export
     :outputs ("installation.tex" "installation.pdf" "installation.xlsx")
     :python-dependencies ("openpyxl"))
    (service-manual
     :filename "service.org"
     :description "Service, maintenance, diagnostics, and blank work records."
     :template "service-manual/template.org"
     :module "engdoc-service"
     :exporter engdoc-service-export
     :outputs ("service.tex" "service.pdf" "service.xlsx")
     :python-dependencies ("openpyxl"))
    (user-manual
     :filename "user-manual.org"
     :description "Controlled safety, operation, recovery, and care guidance."
     :template "user-manual/template.org"
     :module "engdoc-user-manual"
     :exporter engdoc-user-manual-export
     :outputs ("user-manual.tex" "user-manual.pdf" "user-manual.html"
               "user-manual.xlsx")
     :python-dependencies ("openpyxl"))
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

(defun engdoc--document-entry (type)
  "Return the registration entry for document TYPE.
Signal a user error when TYPE is not registered."
  (or (assq type engdoc-document-types)
      (user-error "Unknown engdoc document type: %s" type)))

(defun engdoc--load-document-type (type)
  "Load and return the exporter registered for document TYPE."
  (let* ((entry (engdoc--document-entry type))
         (properties (cdr entry))
         (module (plist-get properties :module))
         (exporter (plist-get properties :exporter)))
    (when module
      (let ((load-path
             (cons (expand-file-name
                    (format "documents/%s" type)
                    engdoc-directory)
                   load-path)))
        (require (intern module))))
    (unless (and exporter (fboundp exporter))
      (error "Exporter unavailable for %s: %s" type exporter))
    exporter))

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
  '("figs" "datasheets" "purchasing" "exports" "records")
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

(defun engdoc-add-document (type directory)
  "Add a document of TYPE to an engdoc project DIRECTORY."
  (interactive
   (list
    (intern (completing-read "Document type: "
                             (engdoc--document-types) nil t))
    (read-directory-name "Project directory: " default-directory)))
  (engdoc-new-document type directory))

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

    ;; Validate relationships before any document replaces existing outputs.
    (when (seq-some
           (lambda (entry)
             (file-exists-p
              (expand-file-name (plist-get (cdr entry) :filename) directory)))
           engdoc-document-types)
      (engdoc-validate-project-set directory))

    (dolist (entry engdoc-document-types)
      (let* ((type (car entry))
             (filename (plist-get (cdr entry) :filename))
             (exporter (plist-get (cdr entry) :exporter))
             (file (expand-file-name filename directory)))

        (when (file-exists-p file)
          (condition-case err
              (progn
                (setq exporter (engdoc--load-document-type type))
                (funcall exporter file)
                (push type exported))

            (error
             (push (cons type (error-message-string err))
                   failed))))))

    (when (and (null failed)
               (engdoc-traceability-applicable-p directory))
      (condition-case err
          (progn
            (engdoc-export-traceability directory)
            (push 'traceability exported))
        (error
         (push (cons 'traceability (error-message-string err)) failed))))

    (setq exported (nreverse exported)
          failed (nreverse failed))

    (if failed
        (progn
          (dolist (failure failed)
            (message "Export failed [%s]: %s"
                     (car failure)
                     (cdr failure)))
          (user-error
           "Exported %d item(s); %d failed. See *Messages*"
           (length exported)
           (length failed)))
      (message "Exported %d item(s): %s"
               (length exported)
               (if exported
                   (mapconcat #'symbol-name exported ", ")
                 "none found")))))

(defun engdoc-project-set-script ()
  "Return the shared project-set validation and traceability script."
  (expand-file-name "export_traceability.py" engdoc-documents-directory))

(defun engdoc-validate-project-set (directory)
  "Validate controlled document relationships beneath DIRECTORY."
  (engdoc-run-python
   (engdoc-project-set-script)
   (list "--validate" (expand-file-name directory))
   "Validating document relationships"))

(defun engdoc-traceability-applicable-p (directory)
  "Return non-nil when DIRECTORY contains traceable source documents."
  (and (file-exists-p (expand-file-name "project.org" directory))
       (file-exists-p (expand-file-name "requirements.org" directory))))

(defun engdoc-export-traceability (directory)
  "Export project-level requirements traceability for DIRECTORY."
  (let ((export-directory
         (engdoc-export-directory (expand-file-name "project.org" directory))))
    (engdoc-with-export-transaction
     export-directory '("traceability.xlsx")
     (lambda (staging-directory)
       (engdoc-run-python
        (engdoc-project-set-script)
        (list (expand-file-name directory)
              (expand-file-name "traceability.xlsx" staging-directory))
        "Exporting requirements traceability")))))

(defun engdoc-batch-export ()
  "Export the project named by ENGDOC_PROJECT_DIRECTORY in batch Emacs.
Use the repository-local virtual environment when it exists and no explicit
`engdoc-python-interpreter' has been configured."
  (let ((directory (getenv "ENGDOC_PROJECT_DIRECTORY"))
        (local-python (expand-file-name ".venv/bin/python" engdoc-directory)))
    (unless (and directory (not (string-empty-p directory)))
      (error "ENGDOC_PROJECT_DIRECTORY is not set"))
    (when (and (null engdoc-python-interpreter)
               (file-executable-p local-python))
      (setq engdoc-python-interpreter local-python))
    (engdoc-check-setup)
    (engdoc-export directory)))

(defun engdoc-export-directory (file)
  "Return the exports directory for FILE, creating it if necessary."
  (let ((directory
         (expand-file-name
          "exports"
          (file-name-directory (expand-file-name file)))))
    (make-directory directory t)
    directory))

(defun engdoc--log (format-string &rest args)
  "Append FORMAT-STRING and ARGS to the engdoc export log."
  (with-current-buffer (get-buffer-create "*engdoc-export*")
    (goto-char (point-max))
    (insert (apply #'format format-string args))))

(defun engdoc-require-executable (program purpose)
  "Return PROGRAM's path or signal an error mentioning PURPOSE."
  (or (executable-find program)
      (error "%s executable not found (%s)" purpose program)))

(defun engdoc-run-process (program args &optional description)
  "Run PROGRAM synchronously with ARGS and report failures clearly.
DESCRIPTION identifies the operation in the shared export log."
  (let* ((description (or description (file-name-nondirectory program)))
         (log-buffer (get-buffer-create "*engdoc-export*")))
    (engdoc--log "\n%s\nCommand: %s %s\n"
                 description program
                 (mapconcat #'shell-quote-argument args " "))
    (let ((status (apply #'process-file program nil log-buffer nil args)))
      (unless (and (integerp status) (zerop status))
        (display-buffer log-buffer)
        (error "%s failed (exit status %s); see *engdoc-export*"
               description status)))))

(defun engdoc-run-python (script args &optional description)
  "Run Python SCRIPT with ARGS, using the configured interpreter."
  (let ((python (engdoc-require-executable (engdoc-python) "Python")))
    (unless (file-exists-p script)
      (error "Python exporter missing: %s" script))
    (engdoc-run-process python (cons script args) description)))

(defun engdoc-verify-outputs (outputs)
  "Signal an error unless every file in OUTPUTS exists and is nonempty."
  (dolist (output outputs)
    (unless (and (file-exists-p output)
                 (> (file-attribute-size (file-attributes output)) 0))
      (error "Expected export missing or empty: %s" output))))

(defun engdoc--commit-outputs (staging-directory export-directory names)
  "Replace NAMES in EXPORT-DIRECTORY with files from STAGING-DIRECTORY.
Restore every previous artifact if any replacement fails."
  (let ((backup-directory
         (make-temp-file
          (expand-file-name ".engdoc-backup-" export-directory) t))
        (backed-up nil)
        (installed nil))
    (condition-case error-data
        (progn
          ;; Preserve the complete old set before replacing any member.
          (dolist (name names)
            (let ((destination (expand-file-name name export-directory))
                  (backup (expand-file-name name backup-directory)))
              (when (file-exists-p destination)
                (make-directory (file-name-directory backup) t)
                (rename-file destination backup)
                (push (cons backup destination) backed-up))))
          (dolist (name names)
            (let ((source (expand-file-name name staging-directory))
                  (destination (expand-file-name name export-directory)))
              (make-directory (file-name-directory destination) t)
              (rename-file source destination)
              (push destination installed)))
          (delete-directory backup-directory t))
      (error
       (dolist (destination installed)
         (when (file-exists-p destination)
           (delete-file destination)))
       (dolist (pair backed-up)
         (when (file-exists-p (car pair))
           (make-directory (file-name-directory (cdr pair)) t)
           (rename-file (car pair) (cdr pair) t)))
       (when (file-exists-p backup-directory)
         (delete-directory backup-directory t))
       (signal (car error-data) (cdr error-data))))))

(defun engdoc-with-export-transaction (export-directory outputs function)
  "Call FUNCTION with a staging directory, then atomically replace OUTPUTS.
No existing artifact in EXPORT-DIRECTORY is changed unless FUNCTION succeeds
and every staged output is present and nonempty. If replacement itself fails,
the previous complete output set is restored."
  (let ((staging-directory
         (make-temp-file
          (expand-file-name ".engdoc-stage-" export-directory) t)))
    (unwind-protect
        (progn
          (funcall function staging-directory)
          (engdoc-verify-outputs
           (mapcar (lambda (name)
                     (expand-file-name name staging-directory))
                   outputs))
          (engdoc--commit-outputs staging-directory export-directory outputs))
      (when (file-exists-p staging-directory)
        (delete-directory staging-directory t)))))

(defun engdoc-check-setup ()
  "Check the local tools and document registrations used by engdoc."
  (interactive)
  (let ((python (engdoc-require-executable (engdoc-python) "Python"))
        (dependencies nil))
    (dolist (entry engdoc-document-types)
      (let ((type (car entry))
            (properties (cdr entry)))
        (dolist (property '(:filename :description :template :module
                            :exporter :outputs))
          (unless (plist-get properties property)
            (error "%s registration is missing %s" type property)))
        (unless (file-exists-p
                 (expand-file-name (plist-get properties :template)
                                   engdoc-documents-directory))
          (error "%s template is missing" type))
        (dolist (dependency (plist-get properties :python-dependencies))
          (cl-pushnew dependency dependencies :test #'string=))
        (engdoc--load-document-type type)))
    (when dependencies
      (engdoc-run-process
       python
       (list "-c" (format "import %s" (mapconcat #'identity dependencies ", ")))
       "Checking Python dependencies"))
    (message "engdoc setup is ready: %d document types, Python %s"
             (length engdoc-document-types) python)))


(provide 'engdoc)

;;; engdoc.el ends here
