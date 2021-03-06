(define (make-interval a b)
  (cons a b))

(define (make-center-width c w)
  (make-interval (- c w) (+ c w)))

(define (center int)
  (/ (+ (lower-bound int) (upper-bound int)) 2))

(define (width int)
  (/ (- (upper-bound int) (lower-bound int)) 2))

(define (percent int)
  (* (/ (width int) (center int)) 100))

(define (make-center-percent c p)
  (make-center-width c (* (/ p 100.0) c)))

(define (lower-bound int)
  (car int))

(define (upper-bound int)
  (cdr int))

(define (add-interval x y)
  (make-interval (+ (lower-bound x) (lower-bound y))
                 (+ (upper-bound x) (upper-bound y))))

(define (sub-interval x y)
  (make-interval (- (lower-bound x) (lower-bound y))
                 (- (upper-bound x) (upper-bound y))))

(define (percent-of-product x y)
  (+ (percent x) (percent y)))

(define (mul-interval x y)
  (cond
   ((and (positive? (lower-bound x)) (positive? (upper-bound x))
         (positive? (lower-bound y)) (positive? (upper-bound y)))
    (make-interval (* (lower-bound x) (lower-bound y))
                   (* (upper-bound x) (upper-bound y))))
   ((and (positive? (lower-bound x)) (positive? (upper-bound x))
         (negative? (lower-bound y)) (positive? (upper-bound y)))
    (make-interval (* (upper-bound x) (lower-bound y))
                   (* (upper-bound x) (upper-bound y))))
   ((and (positive? (lower-bound x)) (positive? (upper-bound x))
         (negative? (lower-bound y)) (negative? (upper-bound y)))
    (make-interval (* (upper-bound x) (lower-bound y))
                   (* (lower-bound x) (upper-bound y))))
   ((and (negative? (lower-bound x)) (positive? (upper-bound x))
         (positive? (lower-bound y)) (positive? (upper-bound y)))
    (make-interval (* (lower-bound x) (upper-bound y))
                   (* (upper-bound x) (upper-bound y))))
   ((and (negative? (lower-bound x)) (positive? (upper-bound x))
         (negative? (lower-bound y)) (positive? (upper-bound y)))
    (make-interval (min (* (lower-bound x) (upper-bound y))
                        (* (lower-bound y) (upper-bound x)))
                   (max (* (upper-bound x) (upper-bound y))
                        (* (lower-bound x) (lower-bound y)))))
   ((and (negative? (lower-bound x)) (positive? (upper-bound x))
         (negative? (lower-bound y)) (negative? (upper-bound y)))
    (make-interval (* (upper-bound x) (lower-bound y))
                   (* (lower-bound x) (lower-bound y))))
   ((and (negative? (lower-bound x)) (negative? (upper-bound x))
         (positive? (lower-bound y)) (positive? (upper-bound y)))
    (make-interval (* (lower-bound x) (upper-bound y))
                   (* (upper-bound x) (lower-bound y))))
   ((and (negative? (lower-bound x)) (negative? (upper-bound x))
         (negative? (lower-bound y)) (positive? (upper-bound y)))
    (make-interval (* (lower-bound x) (upper-bound y))
                   (* (lower-bound x) (lower-bound y))))
   ((and (negative? (lower-bound x)) (negative? (upper-bound x))
         (negative? (lower-bound y)) (negative? (upper-bound y)))
    (make-interval (* (upper-bound x) (upper-bound y))
                   (* (lower-bound x) (lower-bound y))))))

(define (div-interval x y)
  (if (or (= (upper-bound y) 0) (= (lower-bound y) 0))
      (error "Division by zero")
      (mul-interval x
                    (make-interval
                     (/ 1.0 (upper-bound y))
                     (/ 1.0 (lower-bound y))))))

(define (par1 r1 r2)
  (div-interval (mul-interval r1 r2)
                (add-interval r1 r2)))

(define (par2 r1 r2)
  (let ((one (make-interval 1 1)))
    (div-interval one
                  (add-interval (div-interval one r1)
                                (div-interval one r2)))))

(not
 (=
  (width (par1 (make-center-percent 100 0.5) (make-center-percent 200 0.5)))
  (width (par2 (make-center-percent 100 0.5) (make-center-percent 200 0.5)))))
