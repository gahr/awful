;; Copyright (c) 2010-2018, Mario Domenech Goulart
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;; 1. Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;; 2. Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;; 3. The name of the authors may not be used to endorse or promote products
;;    derived from this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
;; IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
;; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
;; IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(module awful
  (;; Parameters
   awful-apps debug-file debug-db-query?
   debug-db-query-prefix db-credentials ajax-library
   enable-ajax ajax-namespace enable-session page-access-control
   page-access-denied-message page-doctype page-css page-charset
   login-page-path main-page-path app-root-path valid-password?
   page-template ajax-invalid-session-message web-repl-access-control
   web-repl-access-denied-message session-inspector-access-control
   session-inspector-access-denied-message page-exception-message
   http-request-variables db-connection page-javascript sid
   enable-javascript-compression javascript-compressor debug-resources
   enable-session-cookie session-cookie-name session-cookie-setter
   awful-response-headers development-mode? enable-web-repl-fancy-editor
   web-repl-fancy-editor-base-uri awful-listen awful-accept awful-backlog
   awful-listener javascript-position awful-resources-table sxml->html
   enable-sxml literal-script/style?

   ;; Procedures
   include-javascript add-javascript add-css debug debug-pp $session
   $session-set! $ $db $db-row-obj define-page undefine-page
   define-session-page ajax ajax-link periodical-ajax login-form
   define-login-trampoline enable-web-repl enable-session-inspector
   awful-version load-apps reload-apps link form redirect-to
   add-request-handler-hook! remove-request-handler-hook! set-page-title!
   html-page

   ;; Macros
   (define-app path-split path-prefix? match-matcher)

   ;; spiffy-request-vars wrapper
   with-request-variables true-boolean-values as-boolean as-list
   as-number as-alist as-vector as-hash-table as-string as-symbol
   nonempty

   ;; Required by the awful server
   add-resource! register-dispatcher register-root-dir-handler awful-start

   ;; Required by db-support eggs
   db-enabled? db-inquirer db-connect db-disconnect sql-quoter db-make-row-obj
   db-query-transformer

   ;; Required by awful-static-pages
   %path-procedure-result

   ) ; end export list

(import scheme)
(cond-expand
  (chicken-4
   ;; Units
   (import chicken data-structures extras files irregex ports srfi-1 srfi-69)
   (use posix srfi-13 tcp utils)

   ;; Eggs
   (use intarweb spiffy spiffy-request-vars uri-common
        http-session json spiffy-cookies sxml-transforms)

   ;; For match-matcher
   (import-for-syntax irregex)

   ;; Special definitions
   (define slurp read-all))

  (chicken-5
   ;; Built-in modules
   (import (chicken base)
           (chicken condition)
           (chicken process-context posix)
           (chicken string)
           (chicken io)
           (chicken irregex)
           (chicken file)
           (chicken fixnum)
           (chicken format)
           (chicken keyword)
           (chicken pathname)
           (chicken platform)
           (chicken port)
           (chicken pretty-print)
           (chicken process-context)
           (chicken tcp)
           (chicken time)
           (chicken time posix)
           (chicken type)
           (chicken string)
           (chicken condition))

   ;; Eggs
   (import intarweb spiffy spiffy-request-vars uri-common
           http-session json spiffy-cookies srfi-1 srfi-13
           srfi-69 sxml-transforms)

   ;; For match-matcher
   (import-for-syntax (chicken irregex))

   ;; Special definitions
   (define (slurp file)
     (with-input-from-file file read-string))

   (define (read-file #!optional (port ##sys#standard-input) (reader read) max)
     (define (slurp port)
       (do ((x (reader port) (reader port))
            (i 0 (fx+ i 1))
            (xs '() (cons x xs)) )
           ((or (eof-object? x) (and max (fx>= i max))) (##sys#fast-reverse xs))))
     (if (port? port)
         (slurp port)
         (call-with-input-file port slurp))))


  (else
   (error "Unsupported CHICKEN version.")))

(include "version.scm")

;;; Parameters

;; User-configurable parameters
(define awful-apps (make-parameter '()))
(define debug-file (make-parameter #f))
(define debug-db-query? (make-parameter #t))
(define debug-db-query-prefix (make-parameter ""))
(define db-credentials (make-parameter #f))
(define ajax-library (make-parameter "//ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"))
(define enable-ajax (make-parameter #f))
(define ajax-namespace (make-parameter "ajax"))
(define enable-session (make-parameter #f))
(define page-access-control (make-parameter (lambda (path) #t)))
(define page-access-denied-message (make-parameter (lambda (path) '(h3 "Access denied."))))
(define page-doctype (make-parameter ""))
(define page-css (make-parameter #f))
(define page-charset (make-parameter #f))
(define login-page-path (make-parameter "/login")) ;; don't forget no-session: #t for this page
(define main-page-path (make-parameter "/"))
(define app-root-path (make-parameter "/"))
(define valid-password? (make-parameter (lambda (user password) #f)))
(define page-template (make-parameter (lambda args (apply html-page args))))
(define ajax-invalid-session-message (make-parameter "Invalid session."))
(define web-repl-access-control (make-parameter (lambda () #f)))
(define web-repl-access-denied-message (make-parameter '(h3 "Access denied.")))
(define session-inspector-access-control (make-parameter (lambda () #f)))
(define session-inspector-access-denied-message (make-parameter '(h3 "Access denied.")))
(define enable-javascript-compression (make-parameter #f))
(define javascript-compressor (make-parameter identity))
(define awful-response-headers (make-parameter #f))
(define development-mode? (make-parameter #f))
(define enable-web-repl-fancy-editor (make-parameter #t))
(define web-repl-fancy-editor-base-uri (make-parameter "http://parenteses.org/awful/codemirror"))
(define page-exception-message
  (make-parameter
   (lambda (exn)
     '(h3 "An error has occurred while processing your request."))))
(define debug-resources (make-parameter #f)) ;; usually useful for awful development debugging
(define enable-session-cookie (make-parameter #t))
(define session-cookie-name (make-parameter "awful-cookie"))
(define session-cookie-setter (make-parameter
                               (lambda (sid)
                                 (set-cookie! (session-cookie-name) sid))))
(define javascript-position (make-parameter 'top))

;; enable-sxml is deprecated and currently unused.
(define enable-sxml (make-parameter #t))

(define literal-script/style? (make-parameter #f))
(define sxml->html
  (make-parameter
   (let ((rules `((literal *preorder* . ,(lambda (t b) b))
                  . ,universal-conversion-rules*)))
     (lambda (sxml)
       (with-output-to-string
         (lambda ()
           (SRV:send-reply (pre-post-order* sxml rules))))))))

;; Parameters for internal use (but exported, since they are internally used by other eggs)
(define http-request-variables (make-parameter #f))
(define db-connection (make-parameter #f))
(define page-javascript (make-parameter ""))
(define sid (make-parameter #f))
(define db-enabled? (make-parameter #f))
(define awful-listen (make-parameter tcp-listen))
(define awful-accept (make-parameter tcp-accept))
(define awful-backlog (make-parameter 100))
(define awful-listener (make-parameter
                        (let ((listener #f))
                          (lambda ()
                            (unless listener
                              (set! listener
                                    ((awful-listen)
                                     (server-port)
                                     (awful-backlog)
                                     (server-bind-address))))
                            listener))))

;; Parameters for internal use and not exported
(define %redirect (make-parameter #f))
(define %web-repl-path (make-parameter #f))
(define %session-inspector-path (make-parameter #f))
(define %error (make-parameter #f))
(define %page-title (make-parameter #f))
(define %page-css (make-parameter #f))

(define-record not-set)
(define not-set (make-not-set))

;; %path-procedure-result is actually exported, because
;; awful-static-pages needs it
(define %path-procedure-result (make-parameter not-set))

;; db-support parameters (set by awful-<db> eggs)
(define missing-db-msg "Database access is not enabled (see `enable-db').")
(define db-inquirer (make-parameter (lambda (query) (error '$db missing-db-msg))))
(define db-connect (make-parameter (lambda (credentials) (error 'db-connect missing-db-msg))))
(define db-disconnect (make-parameter (lambda (connection) (error 'db-disconnect missing-db-msg))))
(define sql-quoter (make-parameter (lambda args (error 'sql-quote missing-db-msg))))
(define db-make-row-obj (make-parameter (lambda (q) (error '$db-row-obj missing-db-msg))))
(define db-query-transformer (make-parameter (lambda (q) q)))

;;; html-page
(define (format-sxml-attribs attribs)
  (if (null? attribs)
      '()
      `((@ ,@attribs))))

(define (apply-tag-attribs/sxml tag attribs . content)
  (cons tag (append (format-sxml-attribs attribs)
                    content)))

(define (html-page contents #!key css title doctype headers charset content-type literal-style? (html-attribs '()) (body-attribs '()))
  (let ((page
         (apply-tag-attribs/sxml
          'html
          html-attribs
          (append
           '(head)
           (if (or charset content-type)
               `((meta (@ (http-equiv "Content-Type")
                          (content
                           ,(string-append (or content-type
                                               "application/xhtml+xml")
                                           "; charset="
                                           (or charset
                                               "UTF-8"))))))
               '())
           (if title `((title ,title)) '())
           (cond ((string? css)
                  `((link (@ (rel "stylesheet")
                             (href ,css)
                             (type "text/css")))))
                 ((list? css)
                  (map (lambda (f)
                         (if (list? f)
                             (let ((data
                                    (slurp (make-pathname (current-directory)
                                                          (car f)))))
                               `(style ,(if literal-style?
                                            `(literal ,data)
                                            data)))
                             `(link (@ (rel "stylesheet")
                                       (href ,f)
                                       (type "text/css")))))
                       css))
                 (else '()))
                  (if headers `(,headers) '()))
          (if (null? contents)
              (apply-tag-attribs/sxml 'body body-attribs)
              (apply-tag-attribs/sxml 'body body-attribs contents)))))
    (if doctype
        (append `((literal ,doctype)) `(,page))
        page)))

;;; Misc
(define (concat args #!optional (sep ""))
  (string-intersperse (map ->string args) sep))

(define-syntax with-request-variables
  (syntax-rules ()
    ((_ bindings body ...) (with-request-vars* $ bindings body ...))))

(define (string->symbol* str)
  (if (string? str)
      (string->symbol str)
      str))

(define (plist->alist pls)
  ;; (plist->alist '(foo: bar baz: quux)) => ((foo bar) (baz quux))
  (let loop ((pls pls)
             (als '()))
    (if (null? pls)
        (reverse! als)
        (let ((hd (string->symbol (keyword->string (car pls))))
              (tl (cdr pls)))
          (if (null? tl)
              (error 'plist->alist pls)
              (loop (cdr tl)
                    (cons (list hd (car tl))
                          als)))))))

(define (load-apps apps)
  (for-each load apps))

(define (reload-apps apps)
  (reset-resources!)
  (when (development-mode?)
    (development-mode-actions))
  (load-apps apps))

(define (define-reload-page)
  ;; Define a /reload page for reloading awful apps
  (define-page "/reload"
    (lambda ()
      (reload-apps (awful-apps))
      `((p "The following awful apps have been reloaded on "
           ,(seconds->string (current-seconds)))
        (ul ,@(map (lambda (app)
                     `(li (code ,app)))
                   (awful-apps)))))
    no-ajax: #t
    title: "Awful reloaded applications"))

(define (development-mode-actions)
  (print "Awful is running in development mode.")
  (debug-log (current-error-port))

  ;; Print the call chain, the error message and links to the
  ;; web-repl and session-inspector (if enabled)
  (page-exception-message
   (lambda (exn)
     `((pre
        ,(with-output-to-string
           (lambda ()
             (print-call-chain)
             (print-error-message exn))))
       (p "[" (a (@ (href ,(or (%web-repl-path) "/web-repl"))) "Web REPL") "]"
          ,(if (enable-session)
               `(" [" (a (@ (href ,(or (%session-inspector-path) "/session-inspector")))
                         "Session inspector") "]")
               '())))))

  ;; If web-repl has not been activated, activate it allowing access
  ;; to the localhost at least (`web-repl-access-control' can be
  ;; used to provide more permissive control)
  (unless (%web-repl-path)
    (let ((old-access-control (web-repl-access-control)))
      (web-repl-access-control
       (lambda ()
         (or (old-access-control)
             (equal? (remote-address) "127.0.0.1")))))
    (enable-web-repl "/web-repl"))

  ;; If session-inspector has not been activated, and if
  ;; `enable-session' is #t, activate it allowing access to the
  ;; localhost at least (`session-inspector-access-control' can be
  ;; used to provide more permissive control)
  (when (and (enable-session) (not (%session-inspector-path)))
    (let ((old-access-control (session-inspector-access-control)))
      (session-inspector-access-control
       (lambda ()
         (or (old-access-control)
             (equal? (remote-address) "127.0.0.1"))))
      (enable-session-inspector "/session-inspector")))

  ;; The reload page
  (define-reload-page))

(define (awful-start thunk #!key dev-mode? port ip-address (use-fancy-web-repl? #t) privileged-code)
  (enable-web-repl-fancy-editor use-fancy-web-repl?)
  (when dev-mode?
    (development-mode? #t)
    (development-mode-actions))
  (when port (server-port port))
  (when ip-address (server-bind-address ip-address))
  ;; if privileged-code is provided, it is loaded before switching
  ;; user/group
  (when privileged-code (privileged-code))
  (let ((listener ((awful-listener))))
    (switch-user/group (spiffy-user) (spiffy-group))
    (when (and (not (eq? (software-type) 'windows))
               (zero? (current-effective-user-id)))
      (print "WARNING: awful is running with administrator privileges (not recommended)"))
    ;; load apps
    (thunk)
    ;; Check for invalid JavaScript positioning
    (unless (memq (javascript-position) '(top bottom))
      (error 'awful-start
             "Invalid value for `javascript-position'.  Valid ones are: `top' and `bottom'."))
    (register-root-dir-handler)
    (register-dispatcher)
    (accept-loop listener (awful-accept))))

(define (get-sid #!optional force-read-sid)
  (and (or (enable-session) force-read-sid)
       (if (enable-session-cookie)
           (or (read-cookie (session-cookie-name)) ($ 'sid))
           ($ 'sid))))

(define (redirect-to new-uri)
  ;; Just set the `%redirect' internal parameter, so `run-resource' is
  ;; able to know where to redirect.
  (%redirect new-uri)
  "")


;;; Application definition
(define (path-split path)
  (cons "/" (string-split path "/")))

(define (path-prefix? prefix path)
  (let ((len-prefix (length prefix)))
    (and (<= len-prefix (length path))
         (equal? prefix (take path len-prefix)))))

(define (match-matcher matcher-obj path thunk)
  (cond ((procedure? matcher-obj)
         (when (matcher-obj path)
           (thunk)))
        ((list? matcher-obj)
         (when (path-prefix? matcher-obj (path-split path))
           (thunk)))
        ((irregex? matcher-obj)
         (when (irregex-match matcher-obj path)
           (thunk)))
        (else (error 'define-app "Unknown matcher object" matcher-obj))))

(define-syntax define-app
  (syntax-rules (matcher: handler-hook: parameters:)
    ((_ id matcher: matcher handler-hook: proc body ...)
     (let ((proc* proc)
           (matcher* matcher))
       (add-request-handler-hook! 'id
         (lambda (path handler)
           (match-matcher matcher* path (lambda () (proc* handler)))))
       (proc* (lambda ()
                body ...))))
    ((_ id matcher: matcher parameters: params body ...)
     (let ((matcher* matcher))
       (add-request-handler-hook! 'id
         (lambda (path handler)
           (match-matcher matcher* path
             (lambda ()
               (parameterize params
                 (handler))))))
       (parameterize params
         body ...)))
    ((_ id matcher: matcher body ...)
     (let ((matcher* matcher))
       (add-request-handler-hook! 'id
         (lambda (path handler)
           (match-matcher matcher* path handler)))
       body ...))))


;;; JavaScript
(define (include-javascript . files)
  (map (lambda (file)
         `(script (@ (type "text/javascript")
                     (src ,file))))
       files))

(define (add-javascript . code)
  (page-javascript (string-append (page-javascript) (concat code))))

(define (maybe-compress-javascript js no-javascript-compression)
  (if (and (enable-javascript-compression)
           (javascript-compressor)
           (not no-javascript-compression))
      (string-trim-both ((javascript-compressor) js))
      js))


;;; CSS
(define (add-css . css)
  (%page-css (string-append (or (%page-css) "")
                            (string-intersperse css ""))))


;;; Debugging
(define (debug . args)
  (cond ((string? (debug-file))
         (with-output-to-file (debug-file)
           (lambda ()
             (print (concat args)))
           append:))
        ((output-port? (debug-file))
         (with-output-to-port (debug-file)
           (lambda ()
             (print (concat args)))))))

(define (debug-pp arg)
  (cond ((string? (debug-file))
         (with-output-to-file (debug-file) (cut pp arg) append:))
        ((output-port? (debug-file))
         (with-output-to-port (debug-file) (cut pp arg)))))


;;; Session access
(define ($session var #!optional default)
  (session-ref (sid) (string->symbol* var) default))

(define ($session-set! var #!optional val)
  (if (list? var)
      (for-each (lambda (var/val)
                  (session-set! (sid) (string->symbol* (car var/val)) (cdr var/val)))
                var)
      (session-set! (sid) (string->symbol* var) val)))

(define (awful-refresh-session!)
  (when (and (enable-session) (session-valid? (sid)))
    (session-refresh! (sid))))


;;; Session-aware procedures for HTML code generation
(define (link url text . rest)
  (let ((pass-sid? (and (not (enable-session-cookie))
                        (sid)
                        (session-valid? (sid))
                        (not (get-keyword no-session: rest))))
        (arguments (or (get-keyword arguments: rest) '()))
        (separator (or (get-keyword separator: rest) ";&")))
    `(a (@ ,@(append
              `((href ,(if url
                           (string-append
                            url
                            (if (or pass-sid? (not (null? arguments)))
                                (string-append
                                 "?"
                                 (form-urlencode
                                  (append arguments
                                          (if pass-sid?
                                              `((sid . ,(sid)))
                                              '()))
                                  separator: separator))
                                ""))
                           "#")))
              (plist->alist rest)))
        ,text)))

(define (form contents . rest)
  (let ((pass-sid? (and (not (enable-session-cookie))
                        (sid)
                        (session-valid? (sid))
                        (not (get-keyword no-session: rest)))))
    `(form (@ ,@(append (plist->alist rest)
                        (list
                         (if pass-sid?
                             `(input (@ (type "hidden")
                                        (name "sid")
                                        (value ,(sid))))
                             '()))))
           ,contents)))


;;; HTTP request variables access
(define ($ var #!optional default/converter)
  (unless (http-request-variables)
    (http-request-variables (request-vars)))
  ((http-request-variables) var default/converter))


;;; DB access
(define ($db q #!key (default '()) values)
  (unless (db-enabled?)
    (error '$db "Database access doesn't seem to be enabled. Did you call `(enable-db)'?"))
  (debug-query q)
  ((db-inquirer) q default: default values: values))

(define (debug-query q)
  (when (and (debug-file) (debug-db-query?))
    (debug (string-append (debug-db-query-prefix) q))))

(define ($db-row-obj q)
  (debug-query q)
  ((db-make-row-obj) q))


;;; Parameters resetting
(define (reset-per-request-parameters) ;; to cope with spiffy's thread reuse
  (http-request-variables #f)
  (awful-response-headers #f)
  (db-connection #f)
  (sid #f)
  (%redirect #f)
  (%error #f)
  (%page-title #f))


;;; Request handling hooks
(define *request-handler-hooks* '())

(define (add-request-handler-hook! name proc)
  (set! *request-handler-hooks*
        (alist-update! name proc *request-handler-hooks*)))

(define (remove-request-handler-hook! name)
  (set! *request-handler-hooks*
        (alist-delete! name *request-handler-hooks*)))

;;; Resources
(root-path (current-directory))

(define *resources* (make-hash-table equal?))

(define (awful-resources-table)
  *resources*)

(define (register-dispatcher)
  (handle-not-found
   (let ((old-handler (handle-not-found)))
     (lambda (_)
       (let* ((path-list (uri-path (request-uri (current-request))))
              (method (request-method (current-request)))
              (path (if (null? (cdr path-list))
                        (car path-list)
                        (string-append "/" (string-intersperse (cdr path-list) "/"))))
              (proc/strict? (resource-ref path (root-path) method)))
         (if proc/strict?
             (run-resource (car proc/strict?) path)
             (if (equal? (last path-list) "") ;; requested path is a
                 ;; dir try to find a procedure with the trailing
                 ;; slash removed and run it _only_ if the resource
                 ;; has been defined as not strict.
                 (let* ((proc/strict? (resource-ref (string-chomp path "/")
                                                    (root-path)
                                                    method))
                        (proc (and proc/strict? (car proc/strict?)))
                        (strict? (and proc/strict? (cdr proc/strict?))))
                   (if (and proc (not strict?))
                       (run-resource proc path)
                       (old-handler _)))
                 (old-handler _))))))))

(define (run-resource proc path)
  (reset-per-request-parameters)
  (let ((handler
         (lambda (path proc)
           (let ((resp (proc path)))
             (if (procedure? resp)
                 (resp)
                 (let ((out (->string resp)))
                   (if (%error)
                       (send-response
                        code: 500
                        reason: "Internal server error"
                        body: (let ((content ((page-exception-message) (%error))))
                                ((sxml->html) content))
                        headers: '((content-type text/html)))
                       (if (%redirect) ;; redirection
                           (let ((new-uri (if (string? (%redirect))
                                              (uri-reference (%redirect))
                                              (%redirect))))
                             (with-headers `((location ,new-uri))
                                           (lambda ()
                                             (send-status 302 "Found"))))
                           (with-headers
                            (append
                             (or (awful-response-headers)
                                 `((content-type text/html)))
                             (or (and-let* ((headers (awful-response-headers))
                                            (content-length (alist-ref 'content-length headers)))
                                   (list (cons 'content-length content-length)))
                                 `((content-length ,(string-length out)))))
                            (lambda ()
                              (write-logged-response)
                              (unless (eq? 'HEAD (request-method (current-request)))
                                (display out (response-port (current-response))))))))))))))
    (call/cc (lambda (continue)
               (for-each (lambda (hook)
                           ((cdr hook) path
                                       (lambda ()
                                         (handler path proc)
                                         (continue #f))))
                         *request-handler-hooks*)
               (handler path proc)))
    ;; The value for %path-procedure-result is determined at path
    ;; matching time, before run-resource is called.  If it was reset
    ;; by reset-per-request-parameters (which is called right at the
    ;; beginning of run-resource), its value would be reset.  So we
    ;; reset it here, after the page handler used its value and
    ;; has finished.
    (%path-procedure-result not-set)))

(define (resource-ref path vhost-root-path method)
  (when (debug-resources)
    (debug-pp (hash-table->alist *resources*)))
  (or (hash-table-ref/default *resources* (list path vhost-root-path method) #f)
      (resource-match/procedure path vhost-root-path method)
      (resource-match/regex path vhost-root-path method)))

(define (resource-match/regex path vhost-root-path method)
  (let loop ((resources (hash-table->alist *resources*)))
    (if (null? resources)
        #f
        (let* ((current-resource (car resources))
               (current-path (caar current-resource))
               (current-vhost (cadar current-resource))
               (current-method (caddar current-resource))
               (current-proc (cdr current-resource)))
          (if (and (irregex? current-path)
                   (equal? current-vhost vhost-root-path)
                   (eq? current-method method)
                   (irregex-match current-path path))
              current-proc
              (loop (cdr resources)))))))

(define (resource-match/procedure path vhost-root-path method)
  (let loop ((resources (hash-table->alist *resources*)))
    (if (null? resources)
        #f
        (let* ((current-resource (car resources))
               (current-path/proc (caar current-resource))
               (current-vhost (cadar current-resource))
               (current-method (caddar current-resource))
               (current-proc (cdr current-resource)))
          (if (and (procedure? current-path/proc)
                   (equal? current-vhost vhost-root-path)
                   (eq? current-method method))
              ;; the arg to be given to the page handler
              (let ((result (current-path/proc path)))
                (if (list? result)
                    (begin
                      (%path-procedure-result result)
                      current-proc)
                    (loop (cdr resources))))
              (loop (cdr resources)))))))

(define (add-resource! path vhost-root-path proc method strict?)
  (let ((methods (if (list? method) method (list method))))
    (for-each
     (lambda (method)
       (let ((upcase-method
              (string->symbol (string-upcase (symbol->string method)))))
         (hash-table-set! *resources*
                          (list path vhost-root-path upcase-method)
                          (cons proc strict?))))
     methods)))

(define (reset-resources!)
  (set! *resources* (make-hash-table equal?)))

;;; Root dir
(define (register-root-dir-handler)
  (handle-directory
   (let ((old-handler (handle-directory)))
     (lambda (path)
       (cond ((resource-ref path (root-path) (request-method (current-request)))
              => (lambda (proc/strict?)
                   (run-resource (car proc/strict?) path)))
             (else (old-handler path)))))))

;;;
;;; Pages
;;;
(define (undefine-page path #!key vhost-root-path (method '(GET HEAD)))
  (for-each (lambda (method)
              (hash-table-delete! *resources*
                                  (list path (or vhost-root-path (root-path))
                                        method)))
            (if (list? method)
                method
                (list method))))

(define (maybe-literal-javascript js)
  (if (literal-script/style?)
      `(literal ,js)
      js))

(define (include-page-javascript ajax? no-javascript-compression)
  (if ajax?
      `(script (@ (type "text/javascript"))
               ,(maybe-literal-javascript
                 (maybe-compress-javascript
                  (string-append
                   "$(document).ready(function(){"
                   (page-javascript) "});")
                  no-javascript-compression)))
      (if (string-null? (page-javascript))
          '()
          `(script (@ (type "text/javascript"))
                   ,(maybe-literal-javascript
                     (maybe-compress-javascript
                      (page-javascript)
                      no-javascript-compression))))))

(define (include-page-css)
  (if (%page-css)
      `(style ,(if (literal-script/style?)
                   `(literal ,(%page-css))
                   (%page-css)))
      ""))

(define (page-path path strict? #!optional namespace)
  (cond ((irregex? path) path)
        ((procedure? path) path)
        ((equal? path "/") (app-root-path))
        (else
         (let ((path (make-pathname (cons (app-root-path)
                                          (if namespace
                                              (list namespace)
                                              '()))
                                    path)))
           (if strict?
               path
               (string-chomp path "/"))))))

(define (set-page-title! title)
  (%page-title title))

;;; Helper procedures for define-page
(define-inline (use-ajax? use-ajax no-ajax)
  (or (string? use-ajax)
      (cond (no-ajax #f)
            ((not (ajax-library)) #f)
            ((and (ajax-library) use-ajax) #t)
            ((enable-ajax) #t)
            (else #f))))

(define-inline (use-session? use-session no-session)
  (or (not (enable-session))
      no-session
      use-session
      (and (enable-session) (session-valid? (sid)))))

(define-inline (apply-page-template contents css title doctype ajax? use-ajax headers
                                    charset no-javascript-compression)
  (let* ((out
          ((page-template)
           contents
           css: (or css (page-css))
           title: (or (%page-title) title)
           doctype: (or doctype (page-doctype))
           headers: `(,(include-page-css)
                      ,(if ajax?
                           `(script (@ (type "text/javascript")
                                       (src ,(if (string? use-ajax)
                                                 use-ajax
                                                 (ajax-library)))))
                           "")
                      ,(or headers '())
                      ,(if (eq? (javascript-position) 'top)
                           (include-page-javascript ajax? no-javascript-compression)
                           '()))
           charset: (or charset (page-charset))
           literal-style?: (literal-script/style?))))
    ((sxml->html) out)))

(define-inline (maybe-create/refresh-session! use-session)
  (when use-session
    (if (session-valid? (sid))
        (awful-refresh-session!)
        (begin
          (sid (session-create))
          ((session-cookie-setter) (sid))))))

(define-inline (render-exception exn)
  (%error exn)
  (debug (with-output-to-string
           (lambda ()
             (print-call-chain)
             (print-error-message exn))))
  ((page-exception-message) exn))

(define-inline (redirect-to-login-page path)
  ((sxml->html)
   `(html
     (head
      (meta (@ (http-equiv "refresh")
               (content
                ,(sprintf
                  "0;url=~a?reason=invalid-session&attempted-path=~a&user=~a~a"
                  (login-page-path)
                  path
                  ($ 'user "")
                  (if (and (not (enable-session-cookie)) ($ 'sid))
                      (string-append "&sid=" ($ 'sid))
                      "")))))))))

(define-inline (render-page contents path given-path no-javascript-compression ajax?)
  (let ((resp
         (cond ((irregex? path)
                (contents given-path))
               ((not (not-set? (%path-procedure-result)))
                (let ((result (%path-procedure-result)))
                  (apply contents result)))
               (else (contents)))))
    (if (procedure? resp)
        ;; eval resp here, where all
        ;; parameters' values are set
        (let ((out (resp))) (lambda () out))
        `(,resp
          ,(if (eq? (javascript-position) 'bottom)
               (include-page-javascript ajax? no-javascript-compression)
               '())))))

(define (define-page path contents #!key css title doctype headers charset no-ajax
                     no-template no-session no-db vhost-root-path no-javascript-compression
                     use-ajax (method '(GET HEAD)) strict
                     use-session) ;; for define-session-page
  (##sys#check-closure contents 'define-page)
  (let ((path (page-path path strict)))
    (add-resource!
     path
     (or vhost-root-path (root-path))
     (lambda (#!optional given-path)
       (sid (get-sid use-session))
       (when (and (db-credentials) (db-enabled?) (not no-db))
         (db-connection ((db-connect) (db-credentials))))
       (page-javascript "")
       (%page-css #f)
       (awful-refresh-session!)
       (let ((out
              (if (use-session? use-session no-session)
                  (if ((page-access-control) (or given-path path))
                      (begin
                        (maybe-create/refresh-session! use-session)
                        (let* ((ajax? (use-ajax? use-ajax no-ajax))
                               (contents
                                (handle-exceptions exn
                                  (render-exception exn)
                                  (render-page contents
                                               path
                                               given-path
                                               no-javascript-compression
                                               ajax?))))
                          (if (%redirect)
                              #f ;; no need to do anything.  Let
                                 ;; `run-resource' perform the redirection
                              (if (procedure? contents)
                                  contents
                                  (if no-template
                                      ((sxml->html) contents)
                                      (apply-page-template contents
                                                           css
                                                           title
                                                           doctype
                                                           ajax?
                                                           use-ajax
                                                           headers
                                                           charset
                                                           no-javascript-compression))))))
                      ((sxml->html)
                       ((page-template)
                        ((page-access-denied-message) (or given-path path)))))
                  (redirect-to-login-page (or given-path path)))))
         (when (and (db-connection) (db-enabled?) (not no-db))
           ((db-disconnect) (db-connection)))
         out))
     method
     strict))
  path)


(define (define-session-page path contents . rest)
  ;; `rest' are same keyword params as for `define-page' (except
  ;; `no-session', obviously)
  (apply define-page (append (list path contents) (list use-session: #t) rest)))


;;; Ajax
(define (->jquery-selector s)
  (if (symbol? s)
      (conc "#" s)
      s))

(define (ajax path id event proc #!key (action 'html) (method 'POST) (arguments '())
              target success no-session no-db no-page-javascript vhost-root-path
              live on content-type prelude update-targets (cache 'not-set) error-handler
              strict)
  (when (and on live)
    (error 'ajax "`live' and `on' cannot be used together."))
  (let ((path (page-path path strict (ajax-namespace))))
    (add-resource! path
                   (or vhost-root-path (root-path))
                   (lambda (#!optional given-path)
                     (sid (get-sid 'force))
                     (when update-targets
                       (awful-response-headers '((content-type "application/json"))))
                     (if (or (not (enable-session))
                             no-session
                             (and (enable-session) (session-valid? (sid))))
                         (if ((page-access-control) path)
                             (begin
                               (when (and (db-credentials) (db-enabled?) (not no-db))
                                 (db-connection ((db-connect) (db-credentials))))
                               (awful-refresh-session!)
                               (let* ((out (if update-targets
                                              (with-output-to-string
                                                (lambda ()
                                                  (json-write
                                                   (list->vector
                                                    (map (lambda (id/content)
                                                           (cons (car id/content)
                                                                 ((sxml->html) (cdr id/content))))
                                                         (proc))))))
                                              ((sxml->html) (proc)))))
                                 (when (and (db-credentials) (db-enabled?) (not no-db))
                                   ((db-disconnect) (db-connection)))
                                 out))
                             ((page-access-denied-message) path))
                         (ajax-invalid-session-message)))
                   method
                   strict)
    (let* ((arguments (if (and (sid) (session-valid? (sid)))
                          (cons `(sid . ,(string-append "'" (sid) "'")) arguments)
                          arguments))
           (js-code
            (string-append
             (if (and id event)
                 (let ((events (concat (if (list? event) event (list event)) " "))
                       (binder (if live "live" (if on "on" "bind"))))
                   (string-append
                    (if on
                        (if (string? on)
                            (sprintf "$('~a')." on) ;; start delegation from `on'
                            "$(document).")
                        (sprintf "$('~a')." (->jquery-selector id)))
                       binder "('" events "',"))
                 "")
                (if (and on (not (boolean? on)))
                    (sprintf "'~a'," (->jquery-selector on))
                    "")
                (string-append
                 "function(event){"
                 (or prelude "")
                 "$.ajax({type:'" (->string method) "',"
                 "url:'" path "',"
                 (if content-type
                     (conc "contentType: '" content-type "',")
                     "")
                 "success:function(response){"
                 (string-append
                     (or success "")
                     ";"
                     (cond (update-targets
                            "$.each(response, function(id, html) { $('#' + id).html(html);});")
                           (target
                            (string-append "$('#" target "')." (->string action) "(response);"))
                           (else "return;")))
                 "},"
                 (if update-targets
                     "dataType: 'json',"
                     "")
                 (if (eq? cache 'not-set)
                     ""
                     (if cache
                         "cache:true,"
                         "cache:false,"))
                 (if error-handler
                     (string-append "error:" error-handler ",")
                     "")
                 (string-append
                  "data:{"
                  (string-intersperse
                   (map (lambda (var/val)
                          (conc  "'" (car var/val) "':" (cdr var/val)))
                        arguments)
                   ",") "}")
                 "})}")
                (if (and id event)
                    ");\n"
                    ""))))
      (unless no-page-javascript (add-javascript js-code))
      js-code)))

(define (periodical-ajax path interval proc #!key target (action 'html) (method 'POST)
                         (arguments '()) success no-session no-db vhost-root-path live on
                         content-type prelude update-targets cache error-handler
                         strict)
  (add-javascript
   (string-append
    "setInterval("
    (ajax path #f #f proc
          target: target
          action: action
          method: method
          arguments: arguments
          success: success
          no-session: no-session
          no-db: no-db
          vhost-root-path: vhost-root-path
          live: live
          on: on
          content-type: content-type
          prelude: prelude
          update-targets: update-targets
          error-handler: error-handler
          cache: cache
          strict: strict
          no-page-javascript: #t)
       ", " (->string interval) ");\n")))

(define (ajax-link path id text proc #!key target (action 'html) (method 'POST) (arguments '())
                   success no-session no-db (event 'click) vhost-root-path live on class
                   hreflang type rel rev charset coords shape accesskey tabindex a-target
                   content-type prelude update-targets error-handler cache strict)
  (ajax path id event proc
        target: target
        action: action
        method: method
        arguments: arguments
        success: success
        no-session: no-session
        vhost-root-path: vhost-root-path
        live: live
        on: on
        content-type: content-type
        prelude: prelude
        update-targets: update-targets
        error-handler: error-handler
        cache: cache
        strict: strict
        no-db: no-db)
  `(a (@ ,(cons '(href "#")
                (filter cadr
                        `((id ,id)
                          (class ,class)
                          (hreflang ,hreflang)
                          (type ,type)
                          (rel ,rel)
                          (rev ,rev)
                          (charset ,charset)
                          (coords ,coords)
                          (shape ,shape)
                          (accesskey ,accesskey)
                          (tabindex ,tabindex)
                          (target ,a-target)))))
      ,text))


;;; Login form
(define (login-form #!key (user-label "User: ")
                          (password-label "Password: ")
                          (submit-label "Submit")
                          (trampoline-path "/login-trampoline")
                          (refill-user #t))
  (let ((attempted-path ($ 'attempted-path))
        (user ($ 'user)))
    `(form (@ (action ,trampoline-path)
              (method "post"))
           ,(if attempted-path
                `(input (@ (type "hidden")
                           (name "attempted-path")
                           (value ,attempted-path)))
                '())
            (span (@ (id "user-container"))
                  (label (@ (id "user-label")
                            (for "user"))
                         ,user-label)
                  (input (@ (type "text")
                            (id "user")
                            (name "user")
                            (value ,(and refill-user user)))))
            (span (@ (id "password-container"))
                  (label (@ (id "password-label")
                            (for "password"))
                         ,password-label)
                  (input (@ (type "password")
                            (id "password")
                            (name "password"))))
            (input (@ (type "submit")
                      (id "login-submit")
                      (value ,submit-label))))))


;;; Login trampoline (for redirection)
(define (define-login-trampoline path #!key vhost-root-path hook)
  (define-page path
    (lambda ()
      (let* ((user ($ 'user))
             (password ($ 'password))
             (attempted-path ($ 'attempted-path))
             (password-valid? ((valid-password?) user password))
             (new-sid (and password-valid? (session-create))))
        (sid new-sid)
        (when (enable-session-cookie)
          ((session-cookie-setter) new-sid))
        (when hook (hook user))
        (html-page
         ""
         headers: `(meta (@ (http-equiv "refresh")
                            (content
                             ,(string-append
                               "0;url="
                               (if new-sid
                                   (string-append
                                    (or attempted-path (main-page-path))
                                    "?user=" user
                                    (if (enable-session-cookie)
                                        ""
                                        (string-append "&sid=" new-sid)))
                                   (string-append
                                    (login-page-path)
                                    "?reason=invalid-password&user="
                                    user)))))))))
    method: 'POST
    vhost-root-path: vhost-root-path
    no-session: #t
    no-template: #t))


;;; Web repl
(define (enable-web-repl path #!key css (title "Awful Web REPL") headers)
  (unless (development-mode?) (%web-repl-path path))

  (define (fancy-editor-js)
    (if (enable-web-repl-fancy-editor)
        `(script (@ (type "text/javascript"))
                 (literal ,(string-append "
  function addClass(element, className) {
    if (!editor.win.hasClass(element, className)) {
      element.className = ((element.className.split(' ')).concat([className])).join(' ');}}

  function removeClass(element, className) {
    if (editor.win.hasClass(element, className)) {
      var classes = element.className.split(' ');
      for (var i = classes.length - 1 ; i >= 0; i--) {
        if (classes[i] === className) {
            classes.splice(i, 1)}}
      element.className = classes.join(' ');}}

  var textarea = document.getElementById('prompt');
  var editor = new CodeMirror(CodeMirror.replace(textarea), {
    height: '250px',
    width: '600px',
    content: textarea.value,
    parserfile: ['" (web-repl-fancy-editor-base-uri) "/tokenizescheme.js',
                 '" (web-repl-fancy-editor-base-uri) "/parsescheme.js'],
    stylesheet:  '" (web-repl-fancy-editor-base-uri) "/schemecolors.css',
    autoMatchParens: true,
    path: '" (web-repl-fancy-editor-base-uri) "/',
    disableSpellcheck: true,
    markParen: function(span, good) {addClass(span, good ? 'good-matching-paren' : 'bad-matching-paren');},
    unmarkParen: function(span) {removeClass(span, 'good-matching-paren'); removeClass(span, 'bad-matching-paren');}
  });")))
        '()))

  (define (web-repl-css)
    (let ((builtin-css
           `(style (@ (type "text/css"))
              ,(string-append
                "h1 { font-size: 18pt; background-color: #898E79; width: 590px; color: white; padding: 5px;}"
                "h2 { font-size: 14pt; background-color: #898E79; width: 590px; color: white; padding: 5px;}"
                "ul#button-bar { margin-left: 0; padding-left: 0; }"
                "#button-bar li {display: inline; list-style-type: none; padding-right: 10px; }"
                (if (enable-web-repl-fancy-editor)
                    "div.border { border: 1px solid black; width: 600px;}"
                    "#prompt { width: 600px; }")
                "#result { border: 1px solid #333; padding: 5px; width: 590px; }"))))
      (if headers
          (append (or css builtin-css) headers)
          (or css builtin-css))))

  (define (web-eval)
    `(pre ,(with-output-to-string
             (lambda ()
               (pp (handle-exceptions exn
                     (begin
                       (print-error-message exn)
                       (print-call-chain))
                     (eval `(begin
                              ,@(with-input-from-string ($ 'code "")
                                  read-file)))))))))

  (define-page path
    (lambda ()
      (if ((web-repl-access-control))
          (begin
            (page-javascript
             (string-append "$('#clear').click(function(){"
                            (if (enable-web-repl-fancy-editor)
                                "editor.setCode('');"
                                "$('#prompt').val('');")
                            "});"))

            (ajax (string-append path "-eval") 'eval 'click web-eval
                  target: "result"
                  arguments: `((code . ,(if (enable-web-repl-fancy-editor)
                                            "editor.getCode()"
                                            "$('#prompt').val()"))))

            (when (enable-web-repl-fancy-editor)
              (ajax (string-append path "-eval") 'eval-region 'click web-eval
                    target: "result"
                    arguments: `((code . "editor.selection()"))))

            `((h1 ,title)
              (h2 "Input area")
              ,(let ((prompt `(textarea (@ (id "prompt")
                                           (name "prompt")
                                           (rows "10")
                                           (cols "90")))))
                 (if (enable-web-repl-fancy-editor)
                     `(div (@ (class "border")) ,prompt)
                     prompt))
              (ul (@ (id "button-bar"))
                  ,(map (lambda (item)
                          `(li (button (@ (id ,(car item))) ,(cdr item))))
                        (append '(("eval"  . "Eval"))
                                (if (enable-web-repl-fancy-editor)
                                    '(("eval-region" . "Eval region"))
                                    '())
                                '(("clear" . "Clear")))))
              (h2 "Output area")
              (div (@ (id "result")))
              ,(fancy-editor-js)))
          (web-repl-access-denied-message)))
    headers: (append
              (if (enable-web-repl-fancy-editor)
                  (include-javascript
                   (make-pathname (web-repl-fancy-editor-base-uri) "codemirror.js")
                   (make-pathname (web-repl-fancy-editor-base-uri) "mirrorframe.js"))
                  '())
              (list (web-repl-css)))
    use-ajax: #t
    title: title
    css: css))


;;; Session inspector
(define (enable-session-inspector path #!key css (title "Awful session inspector") headers)

  (unless (development-mode?)
    (%session-inspector-path path))

  (define builtin-css
    `(style (@ (type "text/css"))
       "h1 { font-size: 16pt; background-color: #898E79; width: 590px; color: white; padding: 5px;}\n"
       ".session-inspector-value { margin: 2px;}\n"
       ".session-inspector-var { margin: 0px; }\n"
       "#session-inspector-table { margin: 0px; width: 600px;}\n"
       "#session-inspector-table tr td, th { padding-left: 10px; border: 1px solid #333; vertical-align: middle; }\n"))

  (define-page path
    (lambda ()
      (parameterize ((enable-session #t))
        (if ((session-inspector-access-control))
            (let ((bindings (session-bindings (sid))))
              `((h1 title)
                ,(if (null? bindings)
                     `(p "Session for sid " ,(sid) " is empty")
                     `((p "Session for " ,(sid))
                       (table (@ (id "session-inspector-table"))
                              (tr (th "Variables")
                                  (th "Values"))
                              ,@(map (lambda (binding)
                                       (let ((var (car binding))
                                             (val (with-output-to-string
                                                    (lambda ()
                                                      (pp (cdr binding))))))
                                         `(tr (td (span (@ (class "session-inspector-var"))
                                                        ,var))
                                              (td (pre (@ (class "session-inspector-value"))
                                                       ,val)))))
                                     bindings))))))
            (session-inspector-access-denied-message))))
    headers: (if headers
                 (append (or css builtin-css) headers)
                 (or css builtin-css))
    title: title
    css: css))

) ; end module
