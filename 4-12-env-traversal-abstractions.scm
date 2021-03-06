;;; WARNING: Don't load this file twice (or you'll lose the primitives
;;; interface, due to renamings of apply).


;;; Data driven dispatch


(define (make-table same-key?)
  (let ((local-table (list '*table*)))
    (define (assoc key records)
      (cond ((null? records) false)
            ((same-key? key (caar records)) (car records))
            (else (assoc key (cdr records)))))
    (define (lookup key-1 key-2)
      (let ((subtable (assoc key-1 (cdr local-table))))
        (if subtable
            (let ((record (assoc key-2 (cdr subtable))))
              (if record
                  (cdr record)
                  false))
            false)))
    (define (insert! key-1 key-2 value)
      (let ((subtable (assoc key-1 (cdr local-table))))
        (if subtable
            (let ((record (assoc key-2 (cdr subtable))))
              (if record
                  (set-cdr! record value)
                  (set-cdr! subtable
                            (cons (cons key-2 value)
                                  (cdr subtable)))))
            (set-cdr! local-table
                      (cons (list key-1
                                  (cons key-2 value))
                            (cdr local-table)))))
      'ok)
    (define (dispatch m)
      (cond ((eq? m 'lookup-proc) lookup)
            ((eq? m 'insert-proc!) insert!)
            (else (error "Unknown operation -- TABLE" m))))
    dispatch))

(define operation-table (make-table eq?))
(define get (operation-table 'lookup-proc))
(define put (operation-table 'insert-proc!))


;;; Main Scheme primitives - eval/apply


(define apply-in-underlying-scheme apply)

(define (eval exp env)
  (cond ((and (list? exp) (get 'eval (car exp)))
         ((get 'eval (car exp)) exp env))
        ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((application? exp)
         (apply (eval (operator exp) env)
                (list-of-values (operands exp) env)))
        (else
         (error "Unknown expression type -- EVAL" exp))))

(define (apply procedure arguments)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure procedure arguments))
        ((compound-procedure? procedure)
         (eval-sequence
           (procedure-body procedure)
           (extend-environment
             (procedure-parameters procedure)
             arguments
             (procedure-environment procedure))))
        (else
         (error
          "Unknown procedure type -- APPLY" procedure))))

(put 'eval 'quote  (lambda (exp env) (text-of-quotation exp)))
(put 'eval 'set!   (lambda (exp env) (eval-assignment exp env)))
(put 'eval 'define (lambda (exp env) (eval-definition exp env)))
(put 'eval 'if     (lambda (exp env) (eval-if exp env)))
(put 'eval 'lambda (lambda (exp env) (make-procedure (lambda-parameters exp) (lambda-body exp) env)))
(put 'eval 'let    (lambda (exp env) (eval (let->combination exp) env)))
(put 'eval 'let*   (lambda (exp env) (eval (let*->nested-lets exp) env)))
(put 'eval 'begin  (lambda (exp env) (eval-sequence (begin-actions exp) env)))
(put 'eval 'cond   (lambda (exp env) (eval (cond->if exp) env)))
(put 'eval 'and    (lambda (exp env) (eval-and exp env)))
(put 'eval 'or     (lambda (exp env) (eval-or exp env)))



;;; Utility functions



(define (tagged-list? exp tag)
  (if (pair? exp)
      (eq? (car exp) tag)
      false))

(define (list-of-values exps env)
  (if (no-operands? exps)
      '()
      (cons (eval (first-operand exps) env)
            (list-of-values (rest-operands exps) env))))

(define (eval-sequence exps env)
  (cond ((last-exp? exps) (eval (first-exp exps) env))
        (else (eval (first-exp exps) env)
              (eval-sequence (rest-exps exps) env))))



;;; Sections for each of the particular expression types



(define (eval-if exp env)
  (if (true? (eval (if-predicate exp) env))
      (eval (if-consequent exp) env)
      (eval (if-alternative exp) env)))



(define (eval-assignment exp env)
  (set-variable-value! (assignment-variable exp)
                       (eval (assignment-value exp) env)
                       env)
  'ok)



(define (eval-definition exp env)
  (define-variable! (definition-variable exp)
                    (eval (definition-value exp) env)
                    env)
  'ok)



(define (self-evaluating? exp)
  (cond ((number? exp) true)
        ((string? exp) true)
        (else false)))



(define (text-of-quotation exp) (cadr exp))

(define (variable? exp) (symbol? exp))



(define (assignment-variable exp) (cadr exp))

(define (assignment-value exp) (caddr exp))


(define (make-definition var val)
  (list 'define var val))

(define (definition-variable exp)
  (if (symbol? (cadr exp))
      (cadr exp)
      (caadr exp)))

(define (definition-value exp)
  (if (symbol? (cadr exp))
      (caddr exp)
      (make-lambda (cdadr exp)
                   (cddr exp))))




(define (lambda-parameters exp) (cadr exp))

(define (lambda-body exp) (cddr exp))

(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))




(define (if-predicate exp) (cadr exp))

(define (if-consequent exp) (caddr exp))

(define (if-alternative exp)
  (if (not (null? (cdddr exp)))
      (cadddr exp)
      'false))

(define (make-if predicate consequent alternative)
  (list 'if predicate consequent alternative))



(define (begin-actions exp) (cdr exp))

(define (last-exp? seq) (null? (cdr seq)))

(define (first-exp seq) (car seq))

(define (rest-exps seq) (cdr seq))

(define (sequence->exp seq)
  (cond ((null? seq) seq)
        ((last-exp? seq) (first-exp seq))
        (else (make-begin seq))))

(define (make-begin seq) (cons 'begin seq))

(define (application? exp) (pair? exp))

(define (operator exp) (car exp))

(define (operands exp) (cdr exp))

(define (no-operands? ops) (null? ops))

(define (first-operand ops) (car ops))

(define (rest-operands ops) (cdr ops))



(define (cond-clauses exp) (cdr exp))

(define (cond-else-clause? clause)
  (eq? (cond-predicate clause) 'else))

(define (cond-predicate clause) (car clause))

(define (cond-actions clause)
  (cdr clause))

(define (cond-send-clause? clause)
  (eq? (cadr clause) '=>))

(define (cond-receiver clause)
  (caddr clause))

(define (cond->if exp)
  (expand-clauses (cond-clauses exp)))

(define (expand-clauses clauses)
  (if (null? clauses)
      'false                          ; no else clause
      (let ((first (car clauses))
            (rest (cdr clauses)))
        (cond
         ((cond-else-clause? first)
          (if (null? rest)
              (sequence->exp (cond-actions first))
              (error "ELSE clause isn't last -- COND->IF"
                     clauses)))
         ((cond-send-clause? first)
          (cons
           (make-lambda
            (list 'condition)
            (list
             (make-if
              'condition
              (cons (cond-receiver first) (list 'condition))
              (expand-clauses rest))))
           (list (cond-predicate first))))
         (else
          (make-if (cond-predicate first)
                   (sequence->exp (cond-actions first))
                   (expand-clauses rest)))))))



(define (let*->nested-lets exp)
  (let bind ((bindings (let-bindings exp)))
    (let ((binding (car bindings)))
      (if (null? (cdr bindings))
          (make-let (list binding) (let-body exp))
          (make-let (list binding) (list (bind (cdr bindings))))))))

(define (let->combination exp)
  (let* ((name (let-name exp))
         (variables (let-variables exp))
         (values (let-vals exp))
         (let-lambda (make-lambda variables (let-body exp))))
    (if name
        (cons
         (make-lambda
          (list)
          (list
           (make-definition name let-lambda)
           (cons name values)))
         (list))
        (cons let-lambda values))))         

(define (let-name exp)
  (let ((name-or-bindings (cadr exp)))
    (if (list? name-or-bindings)
        false
        name-or-bindings)))

(define (let-bindings exp)
  (let ((name-or-bindings (cadr exp)))
    (if (list? name-or-bindings)
        name-or-bindings
        (caddr exp))))

(define (let-variables exp)
  (map car (let-bindings exp)))

(define (let-vals exp)
  (map cadr (let-bindings exp)))

(define (let-body exp)
  (if (let-name exp)
      (cdddr exp)
      (cddr exp)))

(define (make-let bindings body)
  (append (list 'let bindings) body))

(define (make-named-let name bindings body)
  (append (list 'let name bindings) body))



(define (true? x)
  (not (eq? x false)))

(define (false? x)
  (eq? x false))



(define (eval-and exp env)
  (false? (memq false (map (lambda (e) (eval e env)) (cdr exp)))))

(define (eval-or exp env)
  (not (false? (memq true (map (lambda (e) (eval e env)) (cdr exp))))))



(define (make-procedure parameters body env)
  (list 'procedure parameters body env))

(define (compound-procedure? p)
  (tagged-list? p 'procedure))

(define (procedure-parameters p) (cadr p))

(define (procedure-body p) (caddr p))

(define (procedure-environment p) (cadddr p))



(define (enclosing-environment env) (cdr env))

(define (first-frame env) (car env))

(define the-empty-environment '())

(define (make-frame variables values)
  (cons variables values))

(define (frame-variables frame) (car frame))
(define (frame-values frame) (cdr frame))

(define (add-binding-to-frame! var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(define (extend-environment vars vals base-env)
  (if (= (length vars) (length vals))
      (cons (make-frame vars vals) base-env)
      (if (< (length vars) (length vals))
          (error "Too many arguments supplied" vars vals)
          (error "Too few arguments supplied" vars vals))))

(define (frame-lookup frame var)
  (define (frame-lookup-loop vars vals)
    (cond ((null? vars) false)
          ((eq? var (car vars)) vals)
          (else
           (frame-lookup-loop (cdr vars) (cdr vals)))))
  (frame-lookup-loop (frame-variables frame) (frame-values frame)))

(define (environment-lookup env var)
  (if (eq? env the-empty-environment)
      false
      (or (frame-lookup (first-frame env) var)
          (environment-lookup (enclosing-environment env) var))))

(define (lookup-variable-value var env)
  (let ((frame-vals (environment-lookup env var)))
    (if frame-vals
        (car frame-vals)
        (error "Unbound variable" var))))

(define (set-variable-value! var val env)
  (let ((frame-vals (environment-lookup env var)))
    (if frame-vals
        (set-car! frame-vals val)
        (error "Unbound variable -- SET!" var))))

(define (define-variable! var val env)
  (let* ((frame (first-frame env))
         (frame-vals (frame-lookup frame val)))
    (if frame-vals
        (set-car! frame-vals val)
        (add-binding-to-frame! var val frame))))

(define (setup-environment)
  (let ((initial-env
         (extend-environment (primitive-procedure-names)
                             (primitive-procedure-objects)
                             the-empty-environment)))
    (define-variable! 'true true initial-env)
    (define-variable! 'false false initial-env)
    initial-env))

(define (primitive-procedure? proc)
  (tagged-list? proc 'primitive))

(define (primitive-implementation proc) (cadr proc))

(define primitive-procedures
  (list (list 'car car)
        (list 'cdr cdr)
        (list 'cons cons)
        (list 'list list)
        (list 'null? null?)
        (list '+ +)
        (list '- -)
        (list '* *)
        (list '/ /)
        (list '< <)
        (list '> >)
        (list '<= <=)
        (list '>= >=)
        (list 'display display)
        (list 'newline newline)
;;      more primitives
        ))

(define (primitive-procedure-names)
  (map car
       primitive-procedures))

(define (primitive-procedure-objects)
  (map (lambda (proc) (list 'primitive (cadr proc)))
       primitive-procedures))

(define (apply-primitive-procedure proc args)
  (apply-in-underlying-scheme
   (primitive-implementation proc) args))

(define input-prompt ";;; M-Eval input:")

(define output-prompt ";;; M-Eval value:")

(define (driver-loop)
  (prompt-for-input input-prompt)
  (let ((input (read)))
    (let ((output (eval input the-global-environment)))
      (announce-output output-prompt)
      (user-print output)))
  (driver-loop))

(define (prompt-for-input string)
  (newline) (newline) (display string) (newline))

(define (announce-output string)
  (newline) (display string) (newline))

(define (user-print object)
  (if (compound-procedure? object)
      (display (list 'compound-procedure
                     (procedure-parameters object)
                     (procedure-body object)
                     '<procedure-env>))
      (display object)))

(define the-global-environment (setup-environment))

(driver-loop)
