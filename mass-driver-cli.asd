(defsystem "mass-driver-cli"
  :version "0.1.0"
  :description "CLI tool for mass-driver web framework"
  :license "MIT"
  :depends-on ()
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "util" :depends-on ("package"))
                 (:module "commands"
                  :depends-on ("package" "util")
                  :components
                  ((:file "new")
                   (:file "gen-handler")
                   (:file "gen-model")
                   (:file "gen-component")))
                 (:file "main" :depends-on ("package" "commands"))))))
