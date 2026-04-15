(in-package #:mass-driver-cli)

;;; --------------------------------------------------------------------------
;;; mass-driver gen.model <name> [field:type ...]
;;;
;;; Generate:
;;;   - Domain entity (src/domain/<name>/)
;;;   - Infra repo (src/infra/repo/<name>-repo.lisp)
;;;   - Migration file (migrations/<timestamp>_create_<name>s.lisp)
;;; --------------------------------------------------------------------------

(defun cmd-gen-model (args)
  (when (null args)
    (format *error-output* "Usage: mass-driver gen.model <name> [field:type ...]~%")
    (format *error-output* "  Types: string, integer, text, boolean, datetime~%")
    (uiop:quit 1))
  (let* ((name (kebab-case (first args)))
         (fields (mapcar #'parse-field (rest args)))
         (pkg (detect-package)))
    (format t "Generating model: ~a~%" name)

    ;; Domain entity
    (write-file
     (format nil "src/domain/~a/package.lisp" name)
     (gen-domain-package pkg name fields))
    (write-file
     (format nil "src/domain/~a/~a.lisp" name name)
     (gen-domain-entity pkg name fields))

    ;; Infra repo
    (write-file
     (format nil "src/infra/repo/~a-repo.lisp" name)
     (gen-repo pkg name fields))

    ;; Migration
    (let ((migration-file (format nil "migrations/~a_create_~as.lisp"
                                  (timestamp) (snake-case name))))
      (write-file migration-file
                  (gen-migration pkg name fields)))

    (format t "~%Don't forget to:~%")
    (format t "  1. Add the new modules to your .asd~%")
    (format t "  2. Run (connect-db) then (migrate)~%")))

(defun parse-field (field-str)
  "Parse \"email:string\" into (:name \"email\" :type \"string\")."
  (let ((colon (position #\: field-str)))
    (if colon
        (list :name (subseq field-str 0 colon)
              :type (subseq field-str (1+ colon)))
        (list :name field-str :type "string"))))

(defun field-name (field) (getf field :name))
(defun field-type (field) (getf field :type))

(defun cl-col-type (type-str)
  "Convert a CLI type string to Mito col-type."
  (cond
    ((string-equal type-str "string")   "(:varchar 255)")
    ((string-equal type-str "text")     ":text")
    ((string-equal type-str "integer")  ":integer")
    ((string-equal type-str "boolean")  ":boolean")
    ((string-equal type-str "datetime") ":timestamp")
    (t "(:varchar 255)")))

;;; --- Template generators ---

(defun gen-domain-package (pkg name fields)
  (format nil "(defpackage #:~a.domain.~a
  (:use #:cl)
  (:export
   #:~a
   #:make-~a~{~%   #:~a-~a~}
   #:validate-~a
   #:invalid-~a
   #:invalid-~a-reasons))
"
  pkg name
  name name
  (loop for f in fields append (list name (field-name f)))
  name name name))

(defun gen-domain-entity (pkg name fields)
  (format nil "(in-package #:~a.domain.~a)

(defstruct ~a
  id~{~%  ~a~})

(define-condition invalid-~a (error)
  ((reasons :initarg :reasons :reader invalid-~a-reasons))
  (:report (lambda (c stream)
             (format stream \"Invalid ~a: ~~{~~a~~^, ~~}\"
                     (invalid-~a-reasons c)))))

(defun validate-~a (~a)
  \"Validate a ~a entity.\"
  (let ((errors '()))
    ~{~a~}
    (when errors
      (error 'invalid-~a :reasons (nreverse errors)))
    ~a))
"
  pkg name
  name (mapcar #'field-name fields)
  name name name name
  name name name
  (loop for f in fields
        collect (format nil "(when (or (null (~a-~a ~a))
              (and (stringp (~a-~a ~a))
                   (zerop (length (~a-~a ~a)))))
      (push \"~a is required\" errors))
    " name (field-name f) name
      name (field-name f) name
      name (field-name f) name
      (field-name f)))
  name name))

(defun gen-repo (pkg name fields)
  (format nil "(in-package #:~a.infra.~a-repo)

(mass-driver:defmodel ~a-record ()
  (~{~a~^~%   ~}))

(defun to-entity (record)
  (~a.domain.~a:make-~a
   :id (mito:object-id record)~{~%   :~a (~a-record-~a record)~}))

(defun find-by-id (id)
  (let ((record (mito:find-dao '~a-record :id id)))
    (when record (to-entity record))))

(defun list-all ()
  (mapcar #'to-entity (mito:select-dao '~a-record)))

(defun save-entity (entity)
  (let ((record (make-instance '~a-record~{~%                 :~a (~a.domain.~a:~a-~a entity)~})))
    (if (~a.domain.~a:~a-id entity)
        (mito:save-dao record)
        (mito:insert-dao record))
    (to-entity record)))
"
  pkg name
  name
  (loop for f in fields
        collect (format nil "(~a :col-type ~a)" (field-name f) (cl-col-type (field-type f))))
  pkg name name
  (loop for f in fields
        append (list (field-name f) name (field-name f)))
  name name name
  (loop for f in fields
        append (list (field-name f) pkg name name (field-name f)))
  pkg name name))

(defun gen-migration (pkg name fields)
  (declare (ignore pkg))
  (format nil "(in-package #:mass-driver)

(defmigration \"~a_create_~as\"
  :up   (lambda () (auto-migrate))
  :down (lambda ()
          (mito:execute-sql \"DROP TABLE IF EXISTS ~a_record\")))
" (timestamp) (snake-case name) (snake-case name)))
