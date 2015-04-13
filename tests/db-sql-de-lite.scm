(use awful awful-sql-de-lite sql-de-lite)

(define db-file "sqlite-test.db")

(db-credentials db-file)
(enable-db 'sql-de-lite)

(when (file-exists? db-file)
  (delete-file db-file))

(let* ((conn (open-database (db-credentials)))
       (db-query (lambda (q)
                   (query (map-rows (lambda args args))
                          (sql conn q)))))
  (db-query "create table users (name varchar(50), address varchar(50) );")
  (db-query "insert into users (name, address) values ('mario', 'here')")
  (db-query "insert into users (name, address) values ('foo', 'bar')")
  (close-database conn))

(define-page (main-page-path)
  (lambda ()
    `((pre ,(with-output-to-string
              (lambda ()
                (pp ($db "select * from users")))))
      (table
       ,@(map (lambda (row)
                `(tr ,@(map (lambda (i)
                              `(td ,i))
                            row)))
              ($db "select * from users"))))))
