(in-package #:mass-driver-cli)

;;; --------------------------------------------------------------------------
;;; mass-driver gen.handler <name>
;;;
;;; Generate a handler file with index/show/create actions.
;;; --------------------------------------------------------------------------

(defun cmd-gen-handler (args)
  (when (null args)
    (format *error-output* "Usage: mass-driver gen.handler <name>~%")
    (uiop:quit 1))
  (let* ((name (kebab-case (first args)))
         (pkg (detect-package)))
    (format t "Generating handler: ~a~%" name)
    (write-file
     (format nil "src/web/handlers/~a.lisp" name)
     (gen-handler-content pkg name))
    (format t "~%Add routes to your router:~%")
    (format t "  (:get  \"/~a\"     '~a/index)~%" name name)
    (format t "  (:get  \"/~a/:id\" '~a/show)~%" name name)
    (format t "  (:post \"/~a\"     '~a/create)~%" name name)))

(defun gen-handler-content (pkg name)
  (format nil "(in-package #:~a)

(defhandler ~a/index (conn)
  ;; TODO: list all ~a
  (render conn 'pages/~a/index))

(defhandler ~a/show (conn)
  (let ((id (conn-param conn \"id\")))
    ;; TODO: find ~a by id
    (render conn 'pages/~a/show :id id)))

(defhandler ~a/create (conn)
  ;; TODO: create ~a from params
  (flash-put conn :info \"~a created.\")
  (redirect conn \"/~a\"))
" pkg
  name name name
  name name name
  name name
  (string-capitalize name) name))

(defun detect-package ()
  "Detect the project package from area51.lisp or .asd file."
  (let ((config-path "area51.lisp"))
    (if (uiop:file-exists-p config-path)
        (with-open-file (in config-path)
          (let ((*read-eval* nil))
            (let ((form (read in)))
              (if (and (listp form) (string-equal (symbol-name (first form)) "PROJECT"))
                  (second form)
                  "my-app"))))
        "my-app")))
