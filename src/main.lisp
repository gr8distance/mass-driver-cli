(in-package #:mass-driver-cli)

;;; --------------------------------------------------------------------------
;;; CLI entry point
;;; --------------------------------------------------------------------------

(defun main ()
  (let ((args (uiop:command-line-arguments)))
    (if (null args)
        (print-usage)
        (let ((command (first args))
              (rest (rest args)))
          (cond
            ((string= command "new")           (cmd-new rest))
            ((string= command "gen.handler")   (cmd-gen-handler rest))
            ((string= command "gen.model")     (cmd-gen-model rest))
            ((string= command "gen.component") (cmd-gen-component rest))
            ((string= command "help")          (print-usage))
            ((string= command "version")       (format t "mass-driver-cli v0.1.0~%"))
            (t (format *error-output* "Unknown command: ~a~%~%" command)
               (print-usage)
               (uiop:quit 1)))))))

(defun print-usage ()
  (format t "mass-driver — A micro web framework for Common Lisp~%~%")
  (format t "Usage:~%")
  (format t "  mass-driver new <name> [--api] [--database TYPE]  Create a new project~%")
  (format t "    --api               API-only (no HTML views)~%")
  (format t "    --database TYPE     nil | sqlite3 | postgres | mysql (default: sqlite3)~%")
  (format t "  mass-driver gen.handler <name>                 Generate a handler~%")
  (format t "  mass-driver gen.model <name> [field:type ...]  Generate a model~%")
  (format t "  mass-driver gen.component <name>               Generate a component~%")
  (format t "  mass-driver version                            Show version~%")
  (format t "  mass-driver help                               Show this help~%"))
