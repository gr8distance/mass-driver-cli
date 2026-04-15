(in-package #:mass-driver-cli)

;;; --------------------------------------------------------------------------
;;; mass-driver gen.component <name>
;;;
;;; Generate a component file.
;;; --------------------------------------------------------------------------

(defun cmd-gen-component (args)
  (when (null args)
    (format *error-output* "Usage: mass-driver gen.component <name>~%")
    (uiop:quit 1))
  (let* ((name (kebab-case (first args)))
         (pkg (detect-package)))
    (format t "Generating component: ~a~%" name)
    (write-file
     (format nil "src/web/components/~a.lisp" name)
     (format nil "(in-package #:~a)

(defcomponent ~a (&key (class \"\"))
  `(:div :class ,(format nil \"~a ~~a\" class)
     ,@children))
" pkg name name))
    (format t "~%Add to your .asd components list.~%")))
