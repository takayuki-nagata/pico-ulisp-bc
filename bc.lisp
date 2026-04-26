;;; bc.lisp - A "bc" like calculator for uLisp

;; List of supported math functions
(defvar *math-funcs* '(sin cos tan asin acos atan exp log expt sqrt abs round max min))

;; Returns a new list containing the first n elements of lst
(defun take (n lst)
  (if (or (zerop n) (null lst))
      nil
    (cons (car lst) (take (1- n) (cdr lst)))))

;; Finds the last occurrence of any operator in 'ops' within 'lst'
;; Returns a cons cell (operator . index) or nil if not found.
;; Scanning from right to left ensures correct left-associativity for math operations.
(defun last-op (lst ops)
  (let ((idx 0) best-op best-idx)
    (dolist (x lst)
      (when (member x ops)
        (setq best-op x best-idx idx))
      (incf idx))
    (if best-op (cons best-op best-idx) nil)))

;; Returns the tail of the list after skipping the first n elements
(defun nthcdr (n lst)
  (if (or (<= n 0) (null lst))
      lst
    (nthcdr (1- n) (cdr lst))))

;; The core evaluator function for the custom calculator syntax
(defun calc (expr)
  (cond
   ;; Evaluate atoms (variables or literal numbers)
   ((atom expr) 
    (if (symbolp expr) 
        (if (boundp expr) 
            (eval expr) 
          (progn (princ "[Warning: undefined variable] ") 0))
      expr))
   ;; Evaluate block statements enclosed in { }
   ((eq (car expr) '{)
    (let (res)
      (dolist (stmt (cdr expr))
        (unless (eq stmt '})
          (setq res (calc stmt))))
      res))
   ;; Evaluate 'if' statements: (if condition true-branch false-branch)
   ((eq (car expr) 'if)
    (if (calc (cadr expr))
        (calc (caddr expr))
      (when (cdr (cdr (cdr expr))) (calc (car (cdr (cdr (cdr expr))))))))
   ;; Evaluate 'while' loops: (while condition body)
   ((eq (car expr) 'while)
    (loop
     (unless (calc (cadr expr)) (return nil))
     (calc (caddr expr))))
   ;; Evaluate 'print' statements
   ((eq (car expr) 'print)
    (print (calc (cadr expr))))
   ;; Evaluate standard math functions
   ((member (car expr) *math-funcs*)
    (eval (cons (car expr) (mapcar 'calc (cdr expr)))))
   ;; Unwrap single-element lists (e.g., passing through extra parentheses)
   ((null (cdr expr)) (calc (car expr)))
   (t
    ;; Operator precedence parsing: Lowest precedence operators are split first.
    (let ((op-info (or (last-op expr '(=))
                       (last-op expr '(== != < > <= >=))
                       (last-op expr '(+ -))
                       (last-op expr '(* / %)))))
      (if op-info
          (let* ((op (car op-info))
                 (idx (cdr op-info))
                 ;; Split the expression into left and right operands
                 (left (take idx expr))
                 (right (nthcdr (1+ idx) expr)))
            (cond
             ;; Variable assignment creates or updates a global variable
             ((eq op '=)  (let ((val (calc right)))
                            (eval (list 'defvar (car left) val))
                            val))
             ;; Comparison and modulo operations
             ((eq op '==) (= (calc left) (calc right)))
             ((eq op '!=) (not (= (calc left) (calc right))))
             ((eq op '%)  (mod (calc left) (calc right)))
             ;; Standard math operations (+, -, *, /)
             (t (eval (list op (calc left) (calc right))))))
        (calc (car expr)))))))

;; Prints the help manual and syntax examples
(defun show-help ()
  (princ "=== bc-calc mini manual ===") (terpri)
  (princ "Commands:") (terpri)
  (princ "  help : Show this message") (terpri)
  (princ "  quit : Exit REPL") (terpri)
  (terpri)
  (princ "Available Functions:") (terpri)
  (princ "  ") (princ *math-funcs*) (terpri)
  (terpri)
  (princ "Syntax Examples:") (terpri)
  (princ "  Math   : (1 + 2 * 3)") (terpri)
  (princ "  Funcs  : (sqrt (16 + 9))") (terpri)
  (princ "  Assign : (a = 10 % 3)") (terpri)
  (princ "  Block  : ( { (x = 1) (y = 2) } )") (terpri)
  (princ "  If     : (if (x == 1) (print 9) (print 0))") (terpri)
  (princ "  While  : (while (x < 5) ( { (print x) (x = x + 1) } ))") (terpri)
  (terpri)
  (princ "Note: ALWAYS use spaces around operators! (e.g. 'a < 5')") (terpri)
  (princ "===========================") (terpri))

;; The main Read-Eval-Print Loop (REPL) for the calculator
(defun bc ()
  (loop
   (princ "bc> ")
   (let ((input (read)))
     (cond
      ((eq input 'quit)
       (princ "Bye!")
       (terpri)
       (return))
      ((eq input 'help)
       (show-help))
      (t
       (print (calc input))
       (terpri))))))