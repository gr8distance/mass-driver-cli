(in-package #:mass-driver-cli)

;;; --------------------------------------------------------------------------
;;; Utility functions for file generation
;;; --------------------------------------------------------------------------

(defun write-file (path content)
  "Write CONTENT to PATH, creating parent directories as needed."
  (let ((pathname (pathname path)))
    (ensure-directories-exist pathname)
    (with-open-file (out pathname :direction :output :if-exists :supersede)
      (write-string content out))
    (format t "  create ~a~%" path)))

(defun timestamp ()
  "Return a timestamp string like 20260415."
  (multiple-value-bind (sec min hour day month year)
      (get-decoded-time)
    (declare (ignore sec min hour))
    (format nil "~4,'0d~2,'0d~2,'0d" year month day)))

(defun kebab-case (name)
  "Ensure NAME is in kebab-case. Already kebab by convention."
  (string-downcase name))

(defun snake-case (name)
  "Convert kebab-case to snake_case."
  (substitute #\_ #\- (string-downcase name)))

(defun project-path (base &rest parts)
  "Build a path under BASE directory."
  (merge-pathnames (format nil "~{~a~^/~}" parts) (truename base)))
