;;; bc.lisp - A "bc" like calculator for uLisp

;; Built-in Constants
(defvar pi 3.141592653589793)
(defvar e 2.718281828459045)
(defvar phi 1.618033988749895)
(defvar c 299792458)
(defvar g 9.80665)
(defvar h 6.62607015e-34)
(defvar obase 10)

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
   ;; Semicolon separator evaluates left then right (Lowest precedence, applied first)
   ((and (listp expr) (member '_semi_ expr))
    (let* ((op-info (last-op expr '(_semi_)))
           (idx (cdr op-info))
           (left (take idx expr))
           (right (nthcdr (1+ idx) expr)))
      (let ((lval (if left (calc left) nil)))
        (if right (calc right) lval))))
   ;; Evaluate block statements enclosed in { }
   ((eq (car expr) '{)
    (let ((body nil))
      (dolist (x (cdr expr))
        (unless (eq x '})
          (push x body)))
      (setq body (reverse body))
      (if (and body (not (listp (car body))))
          (calc body)
        (let (res)
          (dolist (stmt body)
            (setq res (calc stmt)))
          res))))
   ;; Evaluate 'if' statements: (if condition true-branch [else false-branch])
   ((eq (car expr) 'if)
    (let ((cond-val (calc (cadr expr)))
          (true-branch (caddr expr))
          (rest (cdr (cdr (cdr expr)))))
      (if cond-val
          (calc true-branch)
        (when rest
          (if (eq (car rest) 'else)
              (when (cdr rest) (calc (cadr rest)))
            (calc (car rest)))))))
   ;; Evaluate 'while' loops: (while condition body)
   ((eq (car expr) 'while)
    (loop
     (unless (calc (cadr expr)) (return nil))
     (calc (caddr expr))))
   ;; Evaluate 'print' statements
   ((eq (car expr) 'print)
    (print-result (calc (cadr expr))))
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
  (princ "Built-in Constants:") (terpri)
  (princ "  pi e phi c g h obase") (terpri)
  (terpri)
  (princ "Syntax Examples:") (terpri)
  (princ "  Math   : 1 + 2 * 3") (terpri)
  (princ "  Funcs  : sqrt (16 + 9)") (terpri)
  (princ "  Assign : a = 10 % 3") (terpri)
  (princ "  Ans    : ans * 2 ;; Uses previous result") (terpri)
  (princ "  Block  : { x = 1; y = 2 }") (terpri)
  (princ "  If     : if (x == 1) { print 9 } else { print 0 }") (terpri)
  (princ "  While  : while (x < 5) { print x; x = x + 1 }") (terpri)
  (princ "  Base   : obase = 16 ;; Set output base to 16, 8, 2, or 10") (terpri)
  (terpri)
  (princ "Note: You don't need spaces around operators (e.g. 'a<5' works)") (terpri)
  (princ "===========================") (terpri))

;; Prints the result in the base specified by the global variable 'obase'
(defun print-result (n)
  (let* ((raw-base (if (boundp 'obase) (eval 'obase) 10))
         (base (if (integerp raw-base) raw-base 10)))
    (cond
     ((or (not (integerp n)) (< base 2) (= base 10))
      (print n))
     (t
      (terpri)
      (let ((abs-n (abs n)))
        (when (< n 0) (princ "-"))
        (princ (cond ((= base 16) "#x")
                     ((= base 8)  "#o")
                     ((= base 2)  "#b")
                     (t           "")))
        (let ((res nil))
          (if (= abs-n 0)
              (push 0 res)
            (loop
             (unless (> abs-n 0) (return))
             (push (mod abs-n base) res)
             (setq abs-n (truncate abs-n base))))
          (dolist (d res)
            (princ (if (< d 10) d (code-char (+ 55 d))))))
        (princ " ")
        n)))))

;; Adds spaces around operators and parentheses to allow input without spaces
(defun pad-operators (str)
  (let ((len (length str))
        (i 0)
        (result nil)
        (prev-char #\Space))
    (loop
     (unless (< i len) (return))
     (let ((c (char str i)))
       (incf i)
       (cond
        ;; Two-character operators (==, !=, <=, >=)
        ((and (member c '(#\= #\! #\< #\>))
              (< i len)
              (eq (char str i) #\=))
         (push #\Space result)
         (push c result)
         (push (char str i) result)
         (push #\Space result)
         (incf i)
         (setq prev-char #\=))
        ;; Single-character operators (except minus and braces)
        ((member c '(#\+ #\* #\/ #\% #\= #\< #\> #\( #\)))
         (push #\Space result)
         (push c result)
         (push #\Space result)
         (setq prev-char c))
        ;; Left brace
        ((eq c #\{)
         (push #\Space result)
         (push #\( result)
         (push #\{ result)
         (push #\Space result)
         (setq prev-char c))
        ;; Right brace
        ((eq c #\})
         (push #\Space result)
         (push #\} result)
         (push #\) result)
         (push #\Space result)
         (setq prev-char c))
        ;; Semicolon
        ((eq c #\;)
         (push #\Space result)
         (push #\_ result)
         (push #\s result)
         (push #\e result)
         (push #\m result)
         (push #\i result)
         (push #\_ result)
         (push #\Space result)
         (setq prev-char c))
        ;; Minus sign
        ((eq c #\-)
         (if (and (not (member prev-char '(#\Space #\+ #\- #\* #\/ #\% #\= #\< #\> #\{ #\( )))
                  ;; Exclude exponential notation like 1e-5
                  (not (let ((temp result)
                             (is-exp nil))
                         (loop
                          (unless (and temp (eq (car temp) #\Space)) (return))
                          (setq temp (cdr temp)))
                         (when (and temp (or (eq (car temp) #\e) (eq (car temp) #\E)))
                           (setq temp (cdr temp))
                           (when (and temp (not (member (car temp) '(#\Space #\+ #\- #\* #\/ #\% #\= #\< #\> #\{ #\} #\( #\) ))))
                             (setq is-exp t)))
                         is-exp)))
             (progn
               (push #\Space result)
               (push c result)
               (push #\Space result))
           (push c result))
         (setq prev-char c))
        ;; Other characters
        (t
         (unless (eq c #\Space)
           (setq prev-char c))
         (push c result)))))
    (let ((final-str ""))
      (dolist (ch (reverse result))
        (setq final-str (concatenate 'string final-str (string ch))))
      final-str)))

;; The main Read-Eval-Print Loop (REPL) for the calculator
(defun bc ()
  (loop
   (princ "bc> ")
   (let* ((line (read-line))
          (input (read-from-string (concatenate 'string "(" (pad-operators line) ")"))))
     (cond
      ((or (equal input '(quit)) (equal input '((quit))))
       (princ "Bye!")
       (terpri)
       (return))
      ((or (equal input '(help)) (equal input '((help))))
       (show-help))
      ((null input) nil)
      (t
       (let ((result (calc input)))
         (eval (list 'defvar 'ans result))
         (print-result result)
         (terpri)))))))