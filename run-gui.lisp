#.(progn
    (sb-posix:setenv "DISPLAY" ":0" 1)
    (sb-ext:run-program "/usr/bin/xset" '("s" "off"))
    (sb-ext:run-program "/usr/bin/xset" '("-dpms"))

    (setf asdf:*central-registry* (list "/home/martin/0505/mma/"))
    (ql:quickload "cl-opengl")
    (require :gui)
   ; (require :andor3)
    (require :clara)
   ; (require :mma)
    (require :focus)) 
(defpackage :run-gui
	(:use :cl :gl #-clara :clara
	      ))
(in-package :run-gui)

#+nil
(focus:connect)
#+nil
(focus:get-position)
#+nil
(focus:set-position
 (+ (focus:get-position) .1))

(defvar *mma-chan* nil)
(defvar *binary-fifo* nil)
#+nil
(progn
  (defparameter *mma-chan*
    (sb-ext:run-program "/home/martin/0505/mma/libmma/mma-cmd" '()
			:output :stream
			:input :stream
			:wait nil))
  
  (sb-thread:make-thread 
   #'(lambda ()
       (unwind-protect
	   (with-open-stream (s (sb-ext:process-output *mma-chan*))
	     (loop for line = (read-line s nil nil)
		while line do
		  (format t "read: ~a~%" line)
		  (finish-output)))
	(sb-ext:process-close *mma-chan*)))
   :name "mma-cmd-reader")
  (defparameter *binary-fifo*
    (open "/home/martin/0505/mma/binary_fifo" 
	  :direction :output
	  :if-exists :supersede
	  :if-does-not-exist :error
	  :element-type '(unsigned-byte 16))))

(defun send-binary (img)
      (declare (type (simple-array (unsigned-byte 16) (256 256)) img))
      (let* ((s (sb-ext:process-input *mma-chan*))
	     (n (* 2 (array-total-size img)))
	     (img1 (sb-ext:array-storage-vector img)))
	(write-line (format nil "load ~a" n) s)
	(finish-output s)
	(write-sequence img1 *binary-fifo*)
	(finish-output *binary-fifo*)))

(defparameter *mma-img*
  (let ((a (make-array (list 256 256)
		       :element-type '(unsigned-byte 16))))
    (dotimes (i 256)
      (dotimes (j 256)
	(setf (aref a j i) (if (= 0 (mod (+ i j) 2))
			       4095
			       90))))
    a))
#+nil
(send-binary *mma-img*)

(defun mma (cmd)
  (let ((s (sb-ext:process-input *mma-chan*)))
    (format s "~a~%" cmd)
    (finish-output s)))
#+nil
(mma "white")
#+nil
(mma "black")
#+nil
(mma "img")
#+nil
(mma "splat 118 138 40")
#+nil
(mma "quit")

(defun mma-polar (r phi d)
  (mma (format nil "splat ~a ~a ~a" 
	       (+ 128 (* r (cos phi)))
	       (+ 128 (* r (sin phi)))
	       d)))
#+nil
(mma-polar 128. 45. 20)

#+nil
(mma "set-cycle-time 350")
#+nil
(mma "stop")
#+nil
(mma "off")
#+nil
(mma "start")
#+nil
(mma "quit")
(defun sum (img)
  (destructuring-bind (h w) (array-dimensions img)
    (let ((sum 0))
      (dotimes (j h)
	(dotimes (i w)
	  (incf sum (aref img j i))))
      sum)))


#+nil
(progn
  (defparameter *scan* nil)
  (loop for j below 256 by 2 do
       (loop for i below 256 by 2 do
	    (mma (format nil "splat ~a ~a 7" i j))
	    (capture)
	    (let ((s (list i j (sum *line*))))
	      (format t "~a~%" s)
	      (push s *scan*)))))
#+nil
(capture)
#+nil
(require :vol)
#+nil
(vol:write-pgm "/dev/shm/o.pgm"
 (let* ((d *scan*)
	(fac 2)
	(ma (reduce #'max d :key #'third))
	(mi (reduce #'min d :key #'third))
	(b (make-array (list (/ 256 fac) (/ 256 fac))
		       :element-type '(unsigned-byte 8)))
	(k 0))
   (format t "~a ~a~%" ma mi)
   (dolist (e d)
     (destructuring-bind (i j val) e
       (let ((ii (mod k (/ 256 fac)))
	     (jj (floor k (/ 256 fac))))
	 (incf k)
	 (setf (aref b ii jj)
	       (max 0 (min 255 (floor (* 255 (/ (- val mi)
					       (- ma mi))))))))))
   b))

(defun mma-spot (i j &key (kernel 3))
  (let ((b (make-array (list 256 256)
		       :element-type '(unsigned-byte 16)
		       :initial-element 120)))
    (loop for y from (- kernel) upto kernel do
	 (loop for x from (- kernel) upto kernel do
	      (let ((yy (+ j y))
		    (xx (+ i x)))
		(when (and (<= 0 xx 255)
			   (<= 0 yy 255))
		  (setf (aref b yy xx) 2000)))))
    b))


(defmacro with-lcos-to-cam (&body body)
  `(let* ((s 1.129781s0)
	  (sx  s)
	  (sy  (- s))
	  (phi 0.0 #+nil 1.3154879)
	  (cp (cos phi))
	  (sp (sqrt (- 1s0 (* cp cp))))
	  (tx 800.0)
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
	  (phi 1.0)
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

(defun load-cam-to-lcos-matrix (&optional (x 0s0) (y 0s0))
  (let* ((s .8349911264174253)
	 (sx  s)
	 (sy  (- s))
	 (phi -3.448754960606491)
	 (cp (cos phi))
	 (sp (sqrt (- 1s0 (* cp cp))))
	 (tx 1264.757063764796)
	 (ty 304.7836960672012)
	 (a (make-array (list 4 4) :element-type 'single-float
			 :initial-contents
			 (list (list (* sx cp)    (* sy sp)  .0  (+ x tx))
			       (list (* -1 sx sp) (* sy cp)  .0  (+ y ty))
			       (list .0     .0   1.0  .0)
			       (list .0     .0    .0 1.0)))))
    (gl:load-transpose-matrix (sb-ext:array-storage-vector a))))


(defun draw-circle (x y r)
  (gl:with-primitive :line-loop
   (let ((n 37))
     (loop for i from 0 below n do
	  (let ((arg (* i (/ n) 2 (coerce pi 'single-float)))) 
	    (gl:vertex (+ x (* r (cos arg))) (+ y (* r (sin arg)))))))))

(defun draw-disk (x y r)
  (gl:with-primitive :triangle-fan
   (let ((n 38))
     (gl:vertex x y)
     (loop for i from 0 below n do
	  (let ((arg (* i (/ (1- n)) 2 (coerce pi 'single-float)))) 
	    (gl:vertex (+ x (* r (cos arg))) (+ y (* r (sin arg)))))))))

(defparameter *do-capture* nil)
(defparameter *do-capture* t)

#+nil
(sb-thread:make-thread 
 #'(lambda () 
     (loop while *do-capture* do
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
(change-target 865 630 500 :ril 80s0)
(let* ((px 900s0) (py 600s0) (pr 50s0)
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
  #+nil(change-capture-size 1 1 1392 1040)
  
  (defun draw-screen ()
    (gl:clear-color 0 0 0 1)
    (gl:clear :color-buffer-bit)
    (sleep (/ 60))
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
      (dotimes (i 6) 
	(dotimes (j 3)
	  (draw-disk (+ (* 50 i) px-ill) 
		     (+ (* 50 j) py-ill) 
		     (* .2 pr-ill))))
    (gl:with-pushed-matrix
      (%gl:color-3ub  #b11111110 255  255)
      (gl:translate 0 1024 0)
      (load-cam-to-lcos-matrix 0s0 1024s0)
      (draw-disk px-ill py-ill pr-ill)
      (dotimes (i 6) 
	(dotimes (j 3)
	  (draw-disk (+ (* 50 i) px-ill) 
		     (+ (* 50 j) py-ill) 
		     (* .2 pr-ill))))))

  (defun capture ()
    #-clara (when new-size
      (check
	(set-image 1 1 x w y h))
      (setf new-size nil))
    #+andor3 (defparameter *line*
      (multiple-value-bind (ptr img) (andor3::wait-buffer)
	(let* ((cpy (make-array (array-dimensions img)
				:element-type '(unsigned-byte 16)))
	       (img1 (sb-ext:array-storage-vector img))
	       (cpy1 (sb-ext:array-storage-vector cpy)))
	  (dotimes (i (length cpy1))
	    (setf (aref cpy1 i) (aref img1 i)))
	  (andor3::requeue-buffer ptr)
	  cpy)))
    #-clara (defparameter *line*
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
	   (declare (ignorable h))
	   (dotimes (i (length b1))
	     (let ((v (if (< 20 (aref l1 i))
			  (min 255 (max 0 (floor (aref l1 i) 
						 10)))
			  (let ((yy (floor i w))
				(xx (mod i w)))
			    (cond ((or (= 0 (mod (+ y yy) 500))
				       (= 0 (mod (+ x xx) 500)))
				   255)
				  ((or (= 0 (mod (+ y yy) 100))
				       (= 0 (mod (+ x xx) 100)))
				   80)
				  (t 0))))))
	       (setf (aref b1 i) v))))
	 b)))))
#+nil
(capture)




#+nil
(sb-thread:make-thread 
 #'(lambda ()
     (gui:with-gui (1280 (* 2 1024))
       (draw-screen)))
 :name "display-gui")

