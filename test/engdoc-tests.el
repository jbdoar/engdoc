;;; engdoc-tests.el --- Tests for engdoc -*- lexical-binding: t; -*-

(require 'ert)
(require 'engdoc)

(ert-deftest engdoc-document-registrations-are-complete ()
  (dolist (entry engdoc-document-types)
    (let ((properties (cdr entry)))
      (dolist (property '(:filename :description :template :module
                          :exporter :outputs))
        (should (plist-get properties property)))
      (should (file-exists-p
               (expand-file-name (plist-get properties :template)
                                 engdoc-documents-directory))))))

(ert-deftest engdoc-creates-each-registered-document ()
  (let ((directory (make-temp-file "engdoc-test-" t)))
    (unwind-protect
        (dolist (entry engdoc-document-types)
          (let* ((type (car entry))
                 (filename (plist-get (cdr entry) :filename)))
            (engdoc-new-document type directory)
            (should (file-exists-p (expand-file-name filename directory)))))
      (dolist (buffer (buffer-list))
        (when-let* ((file (buffer-file-name buffer))
                    ((string-prefix-p directory file)))
          (kill-buffer buffer)))
      (delete-directory directory t))))

(ert-deftest engdoc-loads-each-exporter ()
  (dolist (entry engdoc-document-types)
    (should (functionp (engdoc--load-document-type (car entry))))))

(ert-deftest engdoc-init-creates-records-directory ()
  (let ((directory (make-temp-file "engdoc-project-" t)))
    (unwind-protect
        (progn
          ;; engdoc-init expects to create project.org in an otherwise empty dir.
          (engdoc-init directory)
          (should (file-directory-p (expand-file-name "records" directory)))
          (should (file-directory-p (expand-file-name "exports" directory))))
      (dolist (buffer (buffer-list))
        (when-let* ((file (buffer-file-name buffer))
                    ((string-prefix-p directory file)))
          (kill-buffer buffer)))
      (delete-directory directory t))))

(ert-deftest engdoc-reads-shared-metadata ()
  (let* ((file (expand-file-name "test/requirements.org" engdoc-directory))
         (metadata (engdoc-read-metadata file)))
    (should (equal (cdr (assoc "ENGDOC_PROJECT_ID" metadata)) "ENG-0001"))
    (should (equal (cdr (assoc "ENGDOC_DOCUMENT_ID" metadata))
                   "ENG-0001-REQ"))
    (should (equal (cdr (assoc "ENGDOC_STATUS" metadata)) "DRAFT"))))

(ert-deftest engdoc-resolves-default-profile-and-format ()
  (let* ((file (expand-file-name "test/project.org" engdoc-directory))
         (profile (engdoc-profile file))
         (arguments (engdoc-format-arguments file "BOM" "default")))
    (should (equal (plist-get profile :name) "default"))
    (should (file-exists-p
             (expand-file-name "profile.json" (plist-get profile :directory))))
    (should (equal (car arguments) "--format"))
    (should (member "default" arguments))))

(ert-deftest engdoc-export-transaction-preserves-old-set-on-failure ()
  (let ((directory (make-temp-file "engdoc-transaction-" t)))
    (unwind-protect
        (let ((first (expand-file-name "first.txt" directory))
              (second (expand-file-name "second.txt" directory)))
          (with-temp-file first (insert "old first"))
          (with-temp-file second (insert "old second"))
          (should-error
           (engdoc-with-export-transaction
            directory '("first.txt" "second.txt")
            (lambda (staging)
              (with-temp-file (expand-file-name "first.txt" staging)
                (insert "new first")))))
          (should (equal (with-temp-buffer
                           (insert-file-contents first)
                           (buffer-string))
                         "old first"))
          (should (equal (with-temp-buffer
                           (insert-file-contents second)
                           (buffer-string))
                         "old second")))
      (delete-directory directory t))))

(ert-deftest engdoc-export-transaction-replaces-complete-set ()
  (let ((directory (make-temp-file "engdoc-transaction-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "artifact.txt" directory)
            (insert "old"))
          (engdoc-with-export-transaction
           directory '("artifact.txt")
           (lambda (staging)
             (with-temp-file (expand-file-name "artifact.txt" staging)
               (insert "new"))))
          (should (equal (with-temp-buffer
                           (insert-file-contents
                            (expand-file-name "artifact.txt" directory))
                           (buffer-string))
                         "new")))
      (delete-directory directory t))))

(provide 'engdoc-tests)
;;; engdoc-tests.el ends here
