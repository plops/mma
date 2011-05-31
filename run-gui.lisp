#.(progn
    (sb-posix:setenv "DISPLAY" ":0" 1)
    (sb-ext:run-program "/usr/bin/xset" '("s" "off"))
    (sb-ext:run-program "/usr/bin/xset" '("-dpms"))

    (setf asdf:*central-registry* (list "/home/martin/0505/mma/"))
    (ql:quickload "cl-opengl")
    (require :gui)
    (require :clara)
    (require :mma)
    (require :focus)) 
(defpackage :run-gui
	(:use :cl :clara :gl))
(in-package :run-gui)

#+nil
(focus:connect)
#+nil
(focus:get-position)
#+nil
(focus:set-position
 (+ (focus:get-position) -10.))

#+nil
(mma:init)
#+nil 
(mma:init :config "/home/martin/3ini"
	  :calibration "/home/martin/24811567.cal")
#+nil
(mma:uninit)
#+nil
(mma::disconnect)
#+nil
(mma::fill-constant 0)
#+nil
(let* ((width-ms 16s0)
       (delay-us 20s0))
  (check (mma::set-stop-mma))
  (check (mma::set-nominal-deflection-nm  (/ 473s0 4)))
  (check (mma::enable-extern-start))
  (check (mma::set-deflection-phase .0 (* 1000 width-ms)))
  (check (mma::set-extern-ready delay (- (* 1000 width-ms)
				    delay-us)))
  (check (mma::set-cycle-time 140s0))
  (check (mma::set-start-mma)))
#+nil
(mma::set-cycle-time 300s0)

#+nil
(mma::status)



(defmacro with-lcos-to-cam (&body body)
  `(let* ((s 1.129781s0)
	  (sx  s)
	  (sy  (- s))
	  (phi 1.3154879)
	  (cp (cos phi))
	  (sp (sqrt (- 1s0 (* cp cp))))
	  (tx 1086.606s0)
	  (ty 1198.154s0)
	  (a (make-array (list 4 4) :element-type 'single-float
			 :initial-contents
			 (list (list (* sx cp)    (* sy sp)  .0  tx)
			       (list (* -1 sx sp) (* sy cp)  .0  ty)
			       (list .0     .0   1.0  .0)
			       (list .0     .0    .0 1.0)))))
     (gl:with-pushed-matrix
       (gl:load-transpose-matrix (sb-ext:array-storage-vector a))
       ,@body)))

(defmacro with-cam-to-lcos ((&optional (x 0s0) (y 0s0)) &body body)
  `(let* ((s .885090144449)
	  (sx  s)
	  (sy  (- s))
	  (phi 1.3154879)
	  (cp (cos phi))
	  (sp (sqrt (- 1s0 (* cp cp))))
	  (tx 783.23854s0)
	  (ty 1198.40181879s0)
	  (a (make-array (list 4 4) :element-type 'single-float
			 :initial-contents
			 (list (list (* sx cp)    (* sy sp)  .0  (+ ,x tx))
			       (list (* -1 sx sp) (* sy cp)  .0  (+ ,y ty))
			       (list .0     .0   1.0  .0)
			       (list .0     .0    .0 1.0)))))
     (gl:with-pushed-matrix
       (gl:load-transpose-matrix (sb-ext:array-storage-vector a))
       ,@body)))

(defun draw-circle (x y r)
  (gl:with-primitive :line-loop
   (let ((n 37))
     (loop for i from 0 below n do
	  (let ((arg (* i (/ n) 2 (coerce pi 'single-float)))) 
	    (gl:vertex (+ x (* r (cos arg))) (+ y (* r (sin arg)))))))))

(defun draw-disk (x y r)
  (gl:with-primitive :triangle-fan
   (let ((n 37))
     (gl:vertex x y)
     (loop for i from 0 below n do
	  (let ((arg (* i (/ (1- n)) 2 (coerce pi 'single-float)))) 
	    (gl:vertex (+ x (* r (cos arg))) (+ y (* r (sin arg)))))))))



#+nil
(sb-thread:make-thread 
 #'(lambda () 
     (loop
      (capture)
	#+nil
      (sleep .01)))
 :name "capture")

(progn
 (defparameter *t8* nil)
 (defparameter *dark* nil)
 (defparameter *white* nil)
 (defparameter *line* nil))
#+nil
(change-capture-size (+ 380 513) (+ 64 513) 980 650)
#+nil
(change-target 865 630 300 :ril 100s0)
(let* ((px 900s0) (py 600s0) (pr 300s0)
       (px-ill px) (py-ill py) (pr-ill pr)
       (w 1392)
       (h 1040)
       (x 1)
       (y 1)
       (new-size nil))
  (defun change-target (x y r &key (xil x) (yil y) (ril r))
    (setf px x
	  py y
	  pr r
	  px-ill xil
	  py-ill yil
	  pr-ill ril)
    (change-capture-size (max 1 (+ 1 px (- r))) 
			 (max 1 (+ 1 py (- r)))
			 (min 1392 (+ px r))
			 (min 1040 (+ py r))))
  (defun change-capture-size (xx yy ww hh)
    (setf w ww
	  h hh
	  x xx
	  y yy
	  new-size t))
  (change-capture-size 1 1 1392 1040)
  
  (defun draw-screen ()
    (gl:clear-color 0 0 0 1)
    (gl:clear :color-buffer-bit)
    ;;(sleep .1)
    (gl:line-width 1)
    (gl:color 0 1 1)
    (when *t8*
      (gl:with-pushed-matrix
	(gl:translate (- x 1) (- y 1) 0)
	(let ((tex (make-instance 'gui::texture :data *t8*)))
	  (destructuring-bind (h w) (array-dimensions *t8*)
	    (gui:draw tex :w (* 1s0 w) :h (* 1s0 h)
		      :wt 1s0 :ht 1s0))
	  (gui:destroy tex))))
    (gl:color 1 .4 0)
    (gl:line-width 4)
    (draw-circle px py pr)
    (gl:with-pushed-matrix
      (%gl:color-3ub #+nil #b00111111 255 255 255)
      (gl:translate 0 1024 0)
      (with-cam-to-lcos (0 1024)
	(draw-disk px-ill py-ill pr-ill))))

  (defun capture ()
    (when new-size
      (check
	(set-image 1 1 x w y h))
      (setf new-size nil))
   (defparameter *line*
     (let* ((img (make-array (list (- h (1- y)) (- w (1- x)))
			     :element-type '(unsigned-byte 16)))
	    (img1 (sb-ext:array-storage-vector img))
	    (sap (sb-sys:vector-sap img1)))
       (progn
	 (start-acquisition)
	 (loop while (not (eq 'clara::DRV_IDLE
			      (lookup-error (val2 (get-status)))))
	    do
	    (sleep .003))
	 (sb-sys:with-pinned-objects (img)
	   (get-acquired-data16 sap (length img1)))
	 (check
	   (free-internal-memory)))
       img))
   (defparameter *t8*
     (when (and *line*			;*dark* *white* *line*
		)
       (let* ((b (make-array (array-dimensions *line*)
			     :element-type '(unsigned-byte 8)))
	      (b1 (sb-ext:array-storage-vector b))
					;(d1 (sb-ext:array-storage-vector *dark*))
					;(w1 (sb-ext:array-storage-vector *white*))
	      (l1 (sb-ext:array-storage-vector *line*))
	      )
	 (destructuring-bind (h w) (array-dimensions *line*)
	   (dotimes (i (length b1))
	     (let ((v (if t		;(< 800 (aref w1 i)) 
			  (min 255 
			       (max 0 
				    (floor (aref l1 i) 50)
				    #+nil (floor (* 255 (- (aref l1 i) 
							   (aref d1 i)))
						 (- (aref w1 i)
						    (aref d1 i)))))
			  0)))
	       (if (< 1 v)
		   (setf (aref b1 i) 
			 v)
		   (let ((yy (floor i w))
			 (xx (mod i w)))
		     (cond ((or (= 0 (mod (+ y yy) 500))
				(= 0 (mod (+ x xx) 500)))
			    (setf (aref b1 i) 255))
			   ((or (= 0 (mod (+ y yy) 100))
				(= 0 (mod (+ x xx) 100)))
			    (setf (aref b1 i) 80))))))))
	 b)))))
#+nil
(capture)




#+nil
(sb-thread:make-thread 
 #'(lambda ()
     (gui:with-gui (1280 (* 2 1024))
       (draw-screen)))
 :name "display-gui")

