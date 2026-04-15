(in-package #:mass-driver-cli)

;;; --------------------------------------------------------------------------
;;; mass-driver new <name> [options]
;;;
;;; Options:
;;;   --api               API-only (no HTML views, components, layouts)
;;;   --database <type>   nil | sqlite3 | postgres | mysql (default: sqlite3)
;;;
;;; Examples:
;;;   mass-driver new my-app
;;;   mass-driver new my-api --api --database postgres
;;;   mass-driver new my-site --database nil
;;; --------------------------------------------------------------------------

(defun cmd-new (args)
  (when (null args)
    (format *error-output* "Usage: mass-driver new <name> [--api] [--database TYPE]~%")
    (format *error-output* "  --api               API-only (no HTML views)~%")
    (format *error-output* "  --database TYPE     nil | sqlite3 | postgres | mysql~%")
    (uiop:quit 1))
  (multiple-value-bind (name opts) (parse-new-args args)
    (let ((dir (format nil "~a/" name)))
      (when (uiop:directory-exists-p dir)
        (format *error-output* "Directory ~a already exists.~%" name)
        (uiop:quit 1))
      (let ((api-p (getf opts :api))
            (db (getf opts :database :sqlite3)))
        (format t "Creating ~a~a~a...~%"
                name
                (if api-p " (API)" "")
                (if db (format nil " [~a]" db) " [no database]"))
        (generate-project name dir :api-p api-p :db db)
        (format t "~%Done! Next steps:~%")
        (format t "  cd ~a~%" name)
        (format t "  area51 install~%")
        (format t "  area51 run~%")))))

(defun parse-new-args (args)
  "Parse command args into (values name options-plist)."
  (let ((name nil)
        (api-p nil)
        (db :sqlite3)
        (rest args))
    (loop while rest do
      (let ((arg (pop rest)))
        (cond
          ((string= arg "--api") (setf api-p t))
          ((string= arg "--database")
           (let ((val (pop rest)))
             (cond
               ((or (null val) (string= val "nil") (string= val "none"))
                (setf db nil))
               ((string= val "sqlite3")  (setf db :sqlite3))
               ((or (string= val "postgres") (string= val "postgresql"))
                (setf db :postgres))
               ((string= val "mysql")    (setf db :mysql))
               (t (format *error-output* "Unknown database: ~a~%" val)
                  (uiop:quit 1)))))
          ((not name) (setf name (kebab-case arg)))
          (t (format *error-output* "Unknown option: ~a~%" arg)
             (uiop:quit 1)))))
    (unless name
      (format *error-output* "Project name is required.~%")
      (uiop:quit 1))
    (values name (list :api api-p :database db))))

(defun default-database-url (db)
  (case db
    (:sqlite3  "sqlite3:///tmp/~a-dev.db")
    (:postgres "postgres://localhost:5432/~a_dev")
    (:mysql    "mysql://localhost:3306/~a_dev")
    (t nil)))

;;; --------------------------------------------------------------------------
;;; Project generation
;;; --------------------------------------------------------------------------

(defun generate-project (name dir &key api-p db)
  (gen-area51-lisp name dir :api-p api-p :db db)
  (gen-asd-file name dir :api-p api-p :db db)
  (gen-common-files name dir)
  (gen-docker-files name dir :db db)
  (gen-src-base name dir :db db)
  (gen-main-file name dir :api-p api-p :db db)
  (gen-domain-dirs dir)
  (gen-web-handlers name dir :api-p api-p)
  (unless api-p
    (gen-web-views name dir))
  (when db
    (write-file (format nil "~amigrations/.keep" dir) ""))
  (gen-test-files name dir :api-p api-p))

;;; --- area51.lisp ---

(defun gen-area51-lisp (name dir &key api-p db)
  (write-file
   (format nil "~aarea51.lisp" dir)
   (with-output-to-string (s)
     (format s "(project ~s~%" name)
     (format s "  :version \"0.1.0\"~%")
     (format s "  :license \"MIT\"~%")
     (format s "  :entry-point \"main\")~%~%")
     (format s "(deps~%")
     (format s "  (\"mass-driver\" :github \"gr8distance/mass-driver\")~%")
     (format s "  (\"rove\"))~%"))))

;;; --- .asd ---

(defun gen-asd-file (name dir &key api-p db)
  (write-file
   (format nil "~a~a.asd" dir name)
   (with-output-to-string (s)
     (format s "(defsystem ~s~%" name)
     (format s "  :version \"0.1.0\"~%")
     (format s "  :description \"\"~%")
     (format s "  :license \"MIT\"~%")
     (format s "  :depends-on (\"mass-driver\")~%")
     (format s "  :components ((:module \"src\"~%")
     (format s "                :components~%")
     (format s "                ((:file \"package\")~%")
     (format s "                 (:file \"config\" :depends-on (\"package\"))~%")
     (when db
       (format s "                 (:module \"domain\")~%")
       (format s "                 (:module \"db\" :depends-on (\"package\"))~%")
       (format s "                 (:module \"infra\" :depends-on (\"domain\" \"db\"))~%")
       (format s "                 (:module \"app\" :depends-on (\"domain\" \"infra\"))~%"))
     (format s "                 (:module \"web\"~%")
     (format s "                  :depends-on (\"package\" \"config\")~%")
     (format s "                  :components~%")
     (format s "                  ((:module \"handlers\"~%")
     (format s "                    :components ((:file \"page\")))~%")
     (unless api-p
       (format s "                   (:module \"components\"~%")
       (format s "                    :components ((:file \"common\")))~%")
       (format s "                   (:module \"layouts\"~%")
       (format s "                    :components ((:file \"app\")))~%")
       (format s "                   (:module \"pages\"~%")
       (format s "                    :depends-on (\"components\" \"layouts\")~%")
       (format s "                    :components ((:file \"home\")~%")
       (format s "                                 (:file \"about\")))~%"))
     (format s "                   ))~%")
     (format s "                 (:file \"main\" :depends-on (\"package\" \"config\"~a \"web\")))))~%"
             (if db " \"app\"" ""))
     (format s "  :in-order-to ((test-op (test-op ~s))))~%~%" (format nil "~a/tests" name))
     (format s "(defsystem ~s~%" (format nil "~a/tests" name))
     (format s "  :depends-on (~s \"rove\")~%" name)
     (format s "  :components ((:module \"tests\"~%")
     (format s "                :components~%")
     (format s "                ((:file \"package\")~%")
     (format s "                 (:file \"handler-test\" :depends-on (\"package\")))))~%")
     (format s "  :perform (test-op (o c) (symbol-call :rove :run c)))~%"))))

;;; --- Common files ---

(defun gen-common-files (name dir)
  (write-file
   (format nil "~a.gitignore" dir)
   "*.fasl
*.lx64fsl
*.dx64fsl
bin/
tmp/
")
  (write-file
   (format nil "~a.dockerignore" dir)
   ".git
*.fasl
*.lx64fsl
*.dx64fsl
tmp/
"))

;;; --- Docker ---

(defun gen-docker-files (name dir &key db)
  (write-file
   (format nil "~aDockerfile" dir)
   (gen-dockerfile name))
  (write-file
   (format nil "~adocker-compose.yml" dir)
   (gen-docker-compose name db)))

(defun gen-dockerfile (name)
  (format nil "FROM fukamachi/sbcl:latest AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \\
    libev-dev libsqlite3-dev libpq-dev libmariadb-dev \\
    && rm -rf /var/lib/apt/lists/*
COPY . .
RUN if command -v area51 > /dev/null 2>&1; then \\
      area51 install && area51 build; \\
    else \\
      sbcl --non-interactive \\
           --eval '(load (merge-pathnames \"quicklisp/setup.lisp\" (user-homedir-pathname)))' \\
           --eval '(push (truename \".\") asdf:*central-registry*)' \\
           --eval '(ql:quickload ~s)' \\
           --eval '(sb-ext:save-lisp-and-die ~s :toplevel #'\"'\"'~a:main :executable t)'; \\
    fi

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \\
    libev4 libsqlite3-0 libpq5 libmariadb3 ca-certificates \\
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash app
USER app
WORKDIR /home/app
COPY --from=builder /app/~a /home/app/~a
COPY --from=builder /app/static /home/app/static
ENV PORT=3000
EXPOSE 3000
CMD [\"./~a\"]
" name name name name name name))

(defun gen-docker-compose (name db)
  (with-output-to-string (s)
    (format s "services:~%")
    (format s "  app:~%")
    (format s "    build: .~%")
    (format s "    ports:~%")
    (format s "      - \"${PORT:-3000}:3000\"~%")
    (format s "    environment:~%")
    (format s "      - PORT=3000~%")
    (when db
      (format s "      - DATABASE_URL=${DATABASE_URL:-~a}~%"
              (format nil (default-database-url db) name)))
    (format s "      - SECRET_KEY_BASE=${SECRET_KEY_BASE:-dev-secret-change-me-in-prod}~%")
    (case db
      (:postgres
       (format s "    depends_on:~%")
       (format s "      - db~%")
       (format s "~%")
       (format s "  db:~%")
       (format s "    image: postgres:16-alpine~%")
       (format s "    environment:~%")
       (format s "      - POSTGRES_DB=~a_dev~%" (snake-case name))
       (format s "      - POSTGRES_HOST_AUTH_METHOD=trust~%")
       (format s "    ports:~%")
       (format s "      - \"5432:5432\"~%")
       (format s "    volumes:~%")
       (format s "      - db-data:/var/lib/postgresql/data~%"))
      (:mysql
       (format s "    depends_on:~%")
       (format s "      - db~%")
       (format s "~%")
       (format s "  db:~%")
       (format s "    image: mysql:8~%")
       (format s "    environment:~%")
       (format s "      - MYSQL_DATABASE=~a_dev~%" (snake-case name))
       (format s "      - MYSQL_ALLOW_EMPTY_PASSWORD=yes~%")
       (format s "    ports:~%")
       (format s "      - \"3306:3306\"~%")
       (format s "    volumes:~%")
       (format s "      - db-data:/var/lib/mysql~%")))
    (when (member db '(:postgres :mysql))
      (format s "~%volumes:~%  db-data:~%"))))

;;; --- Source files ---

(defun gen-src-base (name dir &key db)
  (write-file
   (format nil "~asrc/package.lisp" dir)
   (format nil "(defpackage #:~a
  (:use #:cl #:mass-driver)
  (:export #:main))
" name))
  (write-file
   (format nil "~asrc/config.lisp" dir)
   (format nil "(in-package #:~a)

;;; App-specific configuration
;;; The framework provides: env, env-int, env-bool, config, reload-config
;;; Add your own config values here:

;; (defparameter *app-name* (env \"APP_NAME\" ~s))
" name name)))

(defun gen-main-file (name dir &key api-p db)
  (write-file
   (format nil "~asrc/main.lisp" dir)
   (with-output-to-string (s)
     (format s "(in-package #:~a)~%~%" name)
     (format s "(defrouter *router*~%")
     (format s "  (pipeline :browser~%")
     (format s "    'logger-middleware~%")
     (format s "    'body-parser-middleware~%")
     (format s "    'session-middleware)~%~%")
     (format s "  (scope \"/\" (:browser)~%")
     (format s "    (:get \"/\"      'page/index)~%")
     (format s "    (:get \"/about\" 'page/about)))~%~%")
     (format s "(defun make-app ()~%")
     (format s "  (lack:builder~%")
     (format s "    (:session)~%")
     (unless api-p
       (format s "    (:static :path (config :static-path)~%")
       (format s "             :root (asdf:system-relative-pathname ~s \"static/\"))~%" name))
     (format s "    (lambda (env)~%")
     (format s "      (dispatch *router* env))))~%~%")
     (format s "(defun start (&key (port (config :port)) (server (config :server)))~%")
     (unless api-p
       (format s "  (compile-styles)~%"))
     (when db
       (format s "  (connect-db)~%"))
     (format s "  (setup-logger)~%")
     (format s "  (log-info \"Starting ~a on port ~~a (~~a)\" port server)~%" name)
     (format s "  (clack:clackup (make-app) :port port :server server))~%~%")
     (format s "(defun main ()~%")
     (format s "  (reload-config)~%")
     (format s "  (start)~%")
     (format s "  (loop (sleep 3600)))~%"))))

(defun gen-domain-dirs (dir)
  (write-file (format nil "~asrc/domain/.keep" dir) "")
  (write-file (format nil "~asrc/app/.keep" dir) "")
  (write-file (format nil "~asrc/infra/repo/.keep" dir) "")
  (write-file (format nil "~asrc/db/.keep" dir) ""))

;;; --- Web handlers ---

(defun gen-web-handlers (name dir &key api-p)
  (write-file
   (format nil "~asrc/web/handlers/page.lisp" dir)
   (if api-p
       (format nil "(in-package #:~a)

(defhandler page/index (conn)
  (respond-json conn '(:status \"ok\" :message \"Welcome to ~a\")))
" name name)
       (format nil "(in-package #:~a)

(defhandler page/index (conn)
  (render conn 'pages/home
          :title ~s
          :message \"Welcome to ~a\"))

(defhandler page/about (conn)
  (render conn 'pages/about
          :title \"About\"))
" name name name))))

;;; --- Views (HTML only) ---

(defun gen-web-views (name dir)
  ;; Components
  (write-file
   (format nil "~asrc/web/components/common.lisp" dir)
   (format nil "(in-package #:~a)

(defcomponent card (title &key (class \"\"))
  `(:div :class ,(format nil \"card ~~a\" class)
     (:h2 ,title)
     (:div :class \"card-body\"
       ,@children)))

(defcomponent navbar (&key (brand ~s))
  `(:nav :class \"navbar\"
     (:div :class \"max-w-5xl mx-auto w-full flex items-center\"
       (:a :href \"/\" :class \"navbar-brand\" ,brand)
       (:div :class \"navbar-links\"
         ,@children))))
" name name))

  ;; Layout
  (write-file
   (format nil "~asrc/web/layouts/app.lisp" dir)
   (format nil "(in-package #:~a)

(deflayout app-layout (&key (title ~s))
  `(progn
     (:doctype)
     (:html :lang \"en\"
       (:head
         (:meta :charset \"utf-8\")
         (:meta :name \"viewport\"
                :content \"width=device-width, initial-scale=1\")
         (:title ,title)
         (:script :src \"https://cdn.tailwindcss.com\")
         (:link :rel \"stylesheet\" :href \"/static/css/app.css\"))
       (:body :class \"min-h-screen bg-gray-50\"
         (navbar
           (:a :href \"/\" \"Home\")
           (:a :href \"/about\" \"About\"))
         ,@children
         (:footer :class \"max-w-5xl mx-auto px-8 py-8 text-center text-sm text-gray-400\"
           \"Powered by \"
           (:a :href \"https://github.com/gr8distance/mass-driver\" :class \"underline\"
             \"mass-driver\"))
         (:script :src \"/static/js/app.js\")))))
" name name))

  ;; Home page
  (write-file
   (format nil "~asrc/web/pages/home.lisp" dir)
   (format nil "(in-package #:~a)

(defview pages/home (title message)
  (app-layout :title title
    (:main :class \"max-w-5xl mx-auto px-8 py-12\"
      (:div :class \"text-center py-12\"
        (:h1 :class \"text-4xl font-bold mb-4 text-gray-900\" message)
        (:p :class \"text-lg text-gray-500 mb-8\"
          \"A micro web framework for Common Lisp\"))
      (:div :class \"grid gap-6 md:grid-cols-3\"
        (card :title \"Components\"
          (:p \"Build reusable UI with \"
              (:code \"defcomponent\") \".\"))
        (card :title \"Routing\"
          (:p \"Phoenix-style DSL with \"
              (:code \"defrouter\") \" and \"
              (:code \"scope\") \".\"))
        (card :title \"Database\"
          (:p \"Models via \"
              (:code \"defmodel\") \", migrations via \"
              (:code \"migrate\") \".\"))))))
" name))

  ;; About page
  (write-file
   (format nil "~asrc/web/pages/about.lisp" dir)
   (format nil "(in-package #:~a)

(defview pages/about (title)
  (app-layout :title title
    (:main :class \"max-w-3xl mx-auto px-8 py-12\"
      (:h1 :class \"text-3xl font-bold mb-6\" \"About\")
      (:div :class \"prose\"
        (:p ~s \" is built with \"
            (:a :href \"https://github.com/gr8distance/mass-driver\" \"mass-driver\")
            \", a micro web framework for Common Lisp.\")
        (:p \"Edit \" (:code \"src/web/pages/about.lisp\") \" to customize this page.\")))))
" name name))

  ;; Static assets
  (write-file
   (format nil "~astatic/css/app.css" dir)
   "/* Generated by Lass — run (compile-styles) to regenerate */
")
  (write-file
   (format nil "~astatic/js/app.js" dir)
   (format nil "// ~a~%" name)))

;;; --- Tests ---

(defun gen-test-files (name dir &key api-p)
  (write-file
   (format nil "~atests/package.lisp" dir)
   (format nil "(defpackage #:~a/tests
  (:use #:cl #:~a #:rove))
" name name))
  (write-file
   (format nil "~atests/handler-test.lisp" dir)
   (if api-p
       (format nil "(in-package #:~a/tests)

(deftest test-index
  (let ((conn (request :get \"/\")))
    (ok (assert-status conn 200))
    (ok (assert-body-contains conn \"Welcome\"))))
" name)
       (format nil "(in-package #:~a/tests)

(deftest test-home-page
  (let ((conn (request :get \"/\")))
    (ok (assert-status conn 200))
    (ok (assert-body-contains conn \"Welcome\"))))
" name))))
