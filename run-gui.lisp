
(eval-when (:compile-toplevel)
  (progn
    (sb-posix:setenv "DISPLAY" ":0" 1)
    (sb-posix:setenv "__GL_SYNC_TO_VBLANK" "1" 1)
    (sb-ext:run-program "/usr/bin/xset" '("s" "off"))
    (sb-ext:run-program "/usr/bin/xset" '("-dpms"))

    (setf asdf:*central-registry* (list "/home/martin/0505/mma/"))
    (ql:quickload "cl-opengl")))
(eval-when (:compile-toplevel)
  (require :gui)
  (require :vol)
  ;; (require :andor3)
  (require :clara)
  ;; (require :mma)
  (require :focus)
  (require :sb-concurrency)
  ;; (require :cl-glut)
  (require :acquisitor)
  ) 
(defpackage :run-gui
  (:use :cl :gl #-clara :clara))
(in-package :run-gui)

#+nil
(unless focus::*fd*
  (focus:connect "/dev/ttyUSB0"))
#+nil
(focus:connect "/dev/ttyUSB1")
#+nil
(focus:get-position)
#+nil
(focus:set-position
 (+ (focus:get-position) -.4s0))

(defvar *mma-chan* nil)
(defvar *binary-fifo* nil)

#+nil
(progn
  (sb-thread:make-thread 
   #'(lambda ()
       (defparameter *mma-chan*
	 (sb-ext:run-program "/home/martin/0505/mma/libmma/mma-cmd" '()
			     :output :stream
			     :input :stream
			     :wait nil))
       (sb-ext:process-wait *mma-chan*))
   :name "mma-waiting-father")
  (sleep .3)
  (sb-thread:make-thread 
   #'(lambda ()
       (unwind-protect
	   (with-open-stream (s (sb-ext:process-output *mma-chan*))
	     (loop for line = (read-line s nil nil)
		while line do
		  (format t "mma read: ~a~%" line)
		  (finish-output)))
	(sb-ext:process-close *mma-chan*)))
   :name "mma-cmd-reader")
  (defparameter *binary-fifo*
    (open "/home/martin/0505/mma/binary_fifo" 
	  :direction :output
	  :if-exists :supersede
	  :if-does-not-exist :error
	  :element-type '(unsigned-byte 16)))
  (mma "set-cycle-time 33.27")
  (send-binary *mma-img*))

(defun send-binary (img)
      (declare (type (simple-array (unsigned-byte 16) (256 256)) img))
      (let* ((s (sb-ext:process-input *mma-chan*))
	     (n (* 2 (array-total-size img)))
	     (img1 (sb-ext:array-storage-vector img)))
	(write-line (format nil "load ~a" n) s)
	(finish-output s)
	(write-sequence img1 *binary-fifo*)
	(finish-output *binary-fifo*)))


(defparameter *mma-imgs*
 (let ((res nil)
       (n 20))
   (dotimes (k n)
     (let* ((arg (* 2 pi (/ k n)))
	    (n 256)
	    (a (make-array (list n n)
			   :element-type '(unsigned-byte 16))))
       (dotimes (i 256)
	 (dotimes (j 256)
	   (let* ((x (+ (- i (floor n 2)) (* 90 (cos arg))))
		  (y (+ (- j (floor n 2)) (* 90 (sin arg))))
		  (r2 (+ (* x x) (* y y))))
	     (setf (aref a j i) (if t #+nil (< r2 (expt 45 2)) 
				    #+nil(= 0 (mod (+ i j) 2))
				    (min 4095 (floor (* 4095 (exp (* -.0004 r2)))))
				    90)))))
       (push a res)))
   (reverse res)))

(defparameter *mma-img*
  (let* ((n 256)
	 (a (make-array (list n n)
		       :element-type '(unsigned-byte 16))))
    (dotimes (i 256)
      (dotimes (j 256)
	(let* () #+nil((x (- i (floor n 2)))
	       (y (- j (floor n 2)))
	       (r2 (+ (* x x) (* y y))))
	  (setf (aref a j i) 4059 #+nil (if t #+nil (< r2 (expt 45 2)) 
					    #+nil(= 0 (mod (+ i j) 2))
					    (min 4095 (floor (* 4095 (exp (* -.0004 r2)))))
					    90)))))
    a))

#+nil
(send-binary *mma-img*)

#+nil
(remove-if-not (lambda (x) (getf x :type)) 
	       (acquisitor:ss :seq))


#+nil
(time
 (store-images-into-mma))


(defun mma (cmd)
  (let ((s (sb-ext:process-input *mma-chan*)))
    (format s "~a~%" cmd)
    (finish-output s)
    (sleep .02)))
#+nil
(mma "white")
#+nil
(mma "black")
#+nil
(mma "set-cycle-time 33.27")
#+nil
(mma "help")
#+nil
(mma "deflection 118.5")
#+nil ;; ANGLE
(let ((n (length *mma-imgs*))
      (i 0))
  (dolist (e *mma-imgs*)
    (send-binary e)
    (mma (format nil "img ~a" (1+ i)))
    (mma (format nil "set-picture-sequence ~a ~a 1" (1+ i) (if (= i (1- n)) 1 0)))
    (incf i)))
#+nil
(let ((i 0)
      (n 1))
 (mma (format nil "set-picture-sequence ~a ~a 1" (1+ i) (if (= i (1- n)) 1 0))))

#+nil
(mma "get-temperature")

#+nil
(mma "frame-voltage 15.0 15.0") ;; 15V should tilt ca. 120nm
#+nil
(progn
  (mma "stop")
  (mma "quit"))
#+nil
(clara::uninit)

(defun load-cam-to-lcos-matrix (&optional (x 0s0) (y 0s0))
  (let* ((s 0.828333873909549)
	 (sx  s)
	 (sy  (- s))
	 (phi -3.101722728951688)
	 (sp (sin phi))
	 (cp (cos phi))
	 (tx 608.4330743004457)
	 (ty 168.9188383630887)
	 (a (make-array (list 4 4) :element-type 'single-float
			 :initial-contents
			 (list (list (* sx cp)    (* sy sp)  .0  (+ x tx))
			       (list (* -1 sx sp) (* sy cp)  .0  (+ y ty))
			       (list .0     .0   1.0  .0)
			       (list .0     .0    .0 1.0)))))
    (gl:load-transpose-matrix (sb-ext:array-storage-vector a))))

(defparameter *do-capture* nil) ;; optionally set *line* to new queue
(defparameter *do-capture* t)
(defparameter *do-display-queue* nil)
(defparameter *do-display-queue* t)
#+nil
(progn
  (sb-thread:make-thread 
  #'(lambda () 
      (start-acquisition)
      (loop while *do-capture* do
	   (capture))
      (abort-acquisition)
      (free-internal-memory))
  :name "capture"))

#+nil ;; turn lcos white
(let ((phases 3))
 (dotimes (j 1)
   (dotimes (i 300)
     (dotimes (k 2)
       (lcos (format nil "qgrating-disk 425.0 325.2 200.1 ~d ~d 12" 
		     (mod i phases) phases))
       ;; (draw-grating-disk 200 225 380 :phase (mod i 3)))
       ;;(lcos "qdisk 200 225 280")
       (sleep .001)
       (lcos "qswap")))
   (sleep .4)
   (lcos "toggle-queue 1")))


#+nil
(sb-thread:make-thread 
 #'(lambda ()  ;; CAPTURE
     
     (progn
       (setf *line* (sb-concurrency:make-queue :name 'picture-fifo))
       
       (clara::prepare-acquisition)

       (progn ;; display a disk ontop of in-focus bead
	 (dotimes (i (length *img-array*))
	   (dotimes (j 2)
	     (lcos "qdisk 225 225 80")
	     (lcos "qswap")))

	 ;; start LCOS
	 (lcos "toggle-queue 1"))

       (let ((n (length *mma-imgs*))) ;; start MMA
	 (dotimes (i n)
	   (mma (format nil "set-picture-sequence ~a ~a 1"
			(1+ i) (if (= i (1- n)) 
				   1 
				   0)))))

       (start-acquisition) ;; start camera
       ;; the first captured frame doesn't have any lcos image
       ;; it can be used as a dark frame

       (let ((count 0))
	 (loop while (and *do-capture*
			  (< count (length *img-array*))) do
	      (capture)
	      (loop for i below (sb-concurrency:queue-count *line*) do
		   (setf (aref *img-array* count)
			 (sb-concurrency:dequeue *line*))
		   (incf count))))
       (abort-acquisition)
       (free-internal-memory)))
 :name "capture")

#+Nil
(mma "start")

(defun transpose-ub16 (img)
  "Transpose the image that comes from the Andor camera."
  (declare (type (simple-array (unsigned-byte 16) 2) img)
	   (values (simple-array (unsigned-byte 16) 2) &optional))
  (let ((dim (array-dimensions img)))
   (destructuring-bind (y x) dim
     (let ((img1 (sb-ext:array-storage-vector img))
	   (r (make-array (list x y) :element-type '(unsigned-byte 16))))
       (vol:do-region ((j i) (y x))
	 (setf (aref r i j) (aref img1 (+ (* y i) j))))
       r))))

(defun transpose-sf (img)
  "Transpose the image that comes from the Andor camera."
  (declare (type (simple-array single-float 2) img)
	   (values (simple-array single-float 2) &optional))
  (let ((dim (array-dimensions img)))
   (destructuring-bind (y x) dim
     (let ((img1 (sb-ext:array-storage-vector img))
	   (r (make-array (list x y) :element-type 'single-float)))
       (vol:do-region ((j i) (y x))
	 (setf (aref r i j) (aref img1 (+ (* y i) j))))
       r))))

(defun maxima (img)
  (destructuring-bind (y x) (array-dimensions img)
    (let ((points ()))
      (vol:do-region ((j i) ((1- y) (1- x)) (1 1))
        (macrolet ((q (n m)
                     `(< (aref img (+ ,n j) (+ ,m i)) e)))
         (let* ((e (aref img j i)))
           (when (and (q 0 1) (q 0 -1)
                      (q 1 0) (q -1 0)
                      (q 1 1) (q 1 -1)
                      (q -1 1) (q -1 -1))
             (push (list e (list j i)) points)))))
      points)))

(defun locate-beads (img)
  (let ((in (transpose-ub16 img)))
    (destructuring-bind (y x) (array-dimensions in)
      (let ((b (vol:normalize-2-csf/ub8-realpart 
		(vol:convolve-circ
		 (vol:draw-disk-csf 9s0 y x)
		 (vol:convert-2-ub16/csf-mul in)))))
	(let ((points
	       (subseq (sort (maxima b) #'(lambda (x y) (< (first y) (first x))))
		       0 4)))
	  (dolist (p points)
	   (destructuring-bind (h (y x)) p
	     (declare (ignore h))
	     (vol:do-region ((j i) ((+ y 2) (+ x 2)) ((- y 2) (- x 2)))
	       (when (and (<= 0 i (1- x))
			  (<= 0 j (1- y)))
		 (setf (aref in j i) 500)))))
	 (vol:write-pgm "/dev/shm/01beads.pgm" 
			(vol:normalize-2-sf/ub8 (vol:convert-2-ub16/sf-mul in)))
	 points)))))


#+nil
(require :vol)
(defvar *line* nil)

(progn
  (defparameter *t8* nil)
  (defparameter *t9* nil)
  (defparameter *phase-im* nil)
  (defparameter *sec* nil)
  (defparameter *dark* nil)
  (defparameter *white* nil)
  (defparameter *line* (sb-concurrency:make-queue :name 'picture-fifo)))

(defparameter *img-array* (make-array (* 100)))
#+nil
(require :vol)
#+nil 
(time ;; STORE
 (let* ((max-threads 4)
	(w (/ (length *img-array*)
	      max-threads)))
   (let ((thr (loop for p below max-threads collect
		   (sb-thread:make-thread
		    (lambda ()
		      (sb-sys:without-gcing
		       (dotimes (i w)
			 (let* ((p (read-from-string (sb-thread:thread-name sb-thread:*current-thread*))) 
				(ii (+ i (* w p))))
			   (when (arrayp (aref *img-array* ii))
			     (vol::write-pgm-transposed 
			      (format nil "/dev/shm/~4,'0d.pgm" ii)
			      (vol:normalize-2-sf/ub8
			       (vol:convert-2-ub16/sf-mul
				(aref *img-array* ii)))))))))
		    :name (format nil "~a" p)))))
     (mapcar #'sb-thread:join-thread thr))))



(let* ((count 0)
       (h 412)
       (w 432)
    #+nil   (px-ill 220s0)
    #+nil   (py-ill 230s0)
    #+nil   (pr-ill 230s0)
       (img-circ (make-array (list 141 #+nil run-clara::*circ-buf-size* h w)
			     :element-type '(unsigned-byte 16))))
  (defun draw-screen ()
    ;;(gl:draw-buffer :back)
    ;(clear-color .1 0 0 1)
    ;(gl:clear :color-buffer-bit)
    
    (let ((c (sb-concurrency:queue-count *line*)))
     (unless (or (= 0 c) (= 1 c))
       (format t "*~a*" c)))
    (when *do-display-queue*
     (loop for e below (sb-concurrency:queue-count *line*) do
	  (let ((e (sb-concurrency:dequeue *line*))
		(p (mod count 5)))
	    (when e
	      (gl:with-pushed-matrix
		(let* ((tex (make-instance 'gui::texture16 :data e
					   :scale 202s0 :offset 0.0077s0
					   )))
		  (destructuring-bind (h w) (array-dimensions e)
		    ;; current image
		    (gui:draw tex :w (* 1s0 w) :h (* 1s0 h)
			      :wt (* h 1s0) :ht (* w 1s0))
		  
		    (with-pushed-matrix 
		      (gl:translate (- 1024 550 (* .25 w (floor p))) 420 0)
		      (gl:scale .25 .25 .25)
		      ;; small copies of earlier images
		      (gui:draw tex :w (* 1s0 w) :h (* 1s0 h)
				:wt (* h 1s0) :ht (* w 1s0))))
		  (gui:destroy tex)))))
	  (incf count)))
    (when (and *mma-imgs* (first *mma-imgs*))
      (let ((cnt 0))
       (dolist (e *mma-imgs*)
	 (with-pushed-matrix
	   ;; mma image
	   (gl:scale .25 .25 .25)
	   (gl:translate (* cnt 256) 2100 0)
	   (incf cnt)
	   (let ((tex (make-instance 'gui::texture16 :data e
				     :scale 16s0 :offset 0s0)))
	     (destructuring-bind (h w) (array-dimensions e)
	       (gui:draw tex :w (* 1s0 w) :h (* 1s0 h)
			 :wt (* h 1s0) :ht (* w 1s0)))
	     (gui:destroy tex))))))
    (acquisitor:draw-moves))

  (defun capture ()
    (let* ((img1 (sb-ext:array-storage-vector img-circ))
	   (sap (sb-sys:vector-sap img1)))
      (destructuring-bind (z y x) (array-dimensions img-circ)
	(declare (ignorable z))
	(check (wait-for-acquisition)) 
	(multiple-value-bind (ret-num-avail first last)
	    (clara::get-number-new-images)
	  (check ret-num-avail)
	  (let ((n (- last first)))
	    (format t "~a" (1+ n))
	    (finish-output)
	    (sb-sys:with-pinned-objects (img-circ)
	      (multiple-value-bind (ret-get16 validfirst validlast)
		  (clara::get-images16 first last sap (* (1+ n) y x))
		(check ret-get16)
		(unless (and 
			 (= validlast last)
			 (= validfirst first))
		  (break "couldn't get as many images as expected ~a"
			 (list first last :valid validfirst validlast)))))
	    (dotimes (k (1+ n))
	      (let ((a (make-array (list y x) 
				   :element-type '(unsigned-byte 16))))
		(dotimes (j y)
		  (dotimes (i x)
		    (setf (aref a j i)
			  (aref img-circ k j i))))
		(sb-concurrency:enqueue a *line*)))))))))

#+nil
(acquisitor:acquire-stack :show-on-screen nil :slices 8 :dz 3 :repetition 1)

#+nil
acquisitor::*stack-state*

#+nil
(loop for e in (acquisitor:reconstruct-from-phase-images :algorithm :sqrt)
     for i = 0 then (1+ i) do
     (vol::write-pgm-transposed (format nil "/dev/shm/r~4,'0d.pgm" i)
				(vol:normalize-2-sf/ub8 e)))

#+nil 
(dotimes (i (length (acquisitor:ss :image-array)))
  ;; store images
  (vol::write-pgm-transposed 
   (format nil "/dev/shm/o~4,'0d.pgm" i)
   (vol:normalize-2-sf/ub8
    (vol:convert-2-ub16/sf-mul (aref (acquisitor:ss :image-array) i)))))

#+nil
(defparameter *volp*
  (let ((sec (acquisitor:reconstruct-from-phase-images :algorithm :sqrt)))
    (destructuring-bind (y x) (array-dimensions (transpose-sf (elt sec 0)))
      (let* ((z (length sec))
	     (a (make-array (list z y x) :element-type 'single-float)))
	(dotimes (k z)
	  (let ((b (transpose-sf (elt sec k))))
	   (vol:do-region ((j i) (y x))
	     (setf (aref a k j i) (aref b j i)))))
	a))))

#+nil
(progn
  (push "/home/martin/0215/0126/bead-eval/" asdf:*central-registry*)
  (push "/home/martin/0215/0102/woropt-cyb-0628/" asdf:*central-registry*)
  (require :bead-eval)
  (require :vol))

#+nil
(progn
  (vol:write-pgm "/dev/shm/op.pgm" 
		 (vol:normalize-2-sf/ub8
		  (vol:cross-section-xz *volp*)))
 (vol:save-stack-ub8 "/dev/shm/op/" 
		     (vol:normalize-3-sf/ub8 *volp*)))

#+nil
(with-open-file (s "/dev/shm/o-sf.dat" :direction :output :if-does-not-exist :create)
  (write *volp* :stream s))

#+nil
(defparameter *volp* 
  (with-open-file (s "/dev/shm/o-sf.dat" :direction :input )
    (read s)))


#+nil
(defparameter *g3* (let ((r 4.2s0)) (bead-eval:make-gauss3 *volp* :sigma-x-pixel r
							 :sigma-z-pixel (/ r 10))))
#+nil
(progn
  (vol:write-pgm "/dev/shm/g3.pgm" 
	       (vol:normalize-2-csf/ub8-realpart
		(vol:cross-section-xz *g3*)))
 (vol:save-stack-ub8 "/dev/shm/g3/" 
		     (vol:normalize-3-csf/ub8-realpart *g3*)))



#+nil
(defparameter *bvol* (vol:convert-3-csf/sf-realpart
		      (vol:convolve-circ-3-csf *g3*
					       (vol:convert-3-sf/csf-mul *volp*))))
#+nil
(progn
  (vol:write-pgm "/dev/shm/op-g.pgm" 
		 (vol:normalize-2-sf/ub8
		  (vol:cross-section-xz *bvol*)))
  (vol:save-stack-ub8 "/dev/shm/op-g/" 
		      (vol:normalize-3-sf/ub8 *bvol*)))

#+nil
(progn
  (defparameter *bvol-thresh* (let* ((a (make-array (array-dimensions *bvol*)
						    :element-type 'single-float))
				     (b1 (sb-ext:array-storage-vector *bvol*))
				     (ma (reduce #'max b1))
				     (mi (reduce #'min b1)))
				(format t "~a~%" (list mi ma))
				(destructuring-bind (z y x) (array-dimensions *bvol*)
				  (vol:do-region ((k j i) (z y x))
				    (setf (aref a k j i)
					  (max (+ mi (* .1 ma))
					       (aref *bvol* k j i)))))
				a))
  (vol:save-stack-ub8 "/dev/shm/op-gt/" (vol:normalize-3-sf/ub8 *bvol-thresh*)))

#+nil
(let ((l (run-ics::nuclear-seeds *bvol-thresh*)))
  (multiple-value-bind (hist n mi ma)
      (run-ics::point-list-histogram l)
    (run-ics::print-histogram hist n (* 10 mi) (* 10 ma))
    (terpri)
    (setf *num-points* (reduce #'+ (subseq hist 5)))))

#+nil
(vol:save-stack-ub8 "/dev/shm/seeds/"
		    (vol:normalize-3-sf/ub8
		     (run-ics::mark-nuclear-seeds *bvol-thresh* :threshold .2)))



#+nil
(defparameter *points*
  (mapcar #'(lambda (v) (destructuring-bind (z y x) (second v)
		     (vol::make-vec (* 1d0 x) (* 1d0 y) (* 10d0 z))))
   (run-ics::biggest-part
    (run-ics::point-list-sort (run-ics::nuclear-seeds *bvol-thresh*))
    .2)))
(defvar *points* nil)

(defun export-3d-model ()
  (with-open-file (s "/dev/shm/model.asy" :direction :output
		     :if-exists :supersede
		     :if-does-not-exist :create)
    (macrolet ((asy (str &rest rest)
		 `(progn
		    (format s ,str ,@rest)
		    (terpri s))))
      (flet ((coord (v)
	       (format nil "(~f,~f,~f)" (vol::vec-x v) (vol::vec-y v) (vol::vec-z v))))
	(asy "import three;~%import grid3;")
	(asy "size(300,300);")
	(let ((i 0))
	 (dolist (e *points*)
	   (incf i)
	   (asy "draw(shift(~a)*scale3(~f)*unitsphere,~a);"
		(coord e) 10
		"lightgreen+opacity(1)")
	   (asy "draw(~a--~a);"
		(coord e)
		(coord
		 (vol::make-vec (vol::vec-x e)
				(vol::vec-y e))))
	   #+nil  (asy "label(~s,~a);" (format nil "~d" i) (coord e))))
	(asy "grid3(XYZgrid);")))))

#+nil
(export-3d-model)
;scp -r martin@cyberpower:/dev/shm/model.asy .;asy -V model.asy



#+nil
(let ((x 700)
      (y 100))
  (progn
    (setf gui::*kill-window* t)
    (sleep .1)
    (setf gui::*kill-window* nil))
  (sb-posix:setenv "DISPLAY" ":0" 1)
  (sb-thread:make-thread
   #'(lambda ()
       (gui:with-gui ((- 1280 x) 700 x y)
	 (draw-screen)))
   :name "camera-display"))

#+nil
(gui:get-frame-rate)

#+nil
(progn ;; destroy lisp opengl window
    (setf gui::*kill-window* t)
    (sleep .1)
    (setf gui::*kill-window* nil))


(defparameter *lcos-chan* nil)
(defun lcos (cmd)
  (let ((s (sb-ext:process-input *lcos-chan*)))
    (format s "~a~%" cmd)
    (finish-output s)
    (force-output s)
    (sleep .001)))

#+nil
(progn
  (sb-posix:setenv "DISPLAY" ":0" 1)
  (sb-posix:setenv "__GL_SYNC_TO_VBLANK" "1" 1)
  (sb-thread:make-thread
   #'(lambda () 
       (setf *lcos-chan*
	     (sb-ext:run-program
	      "/home/martin/0505/mma/glfw-server/glfw"
	      '("1280" "1024")
	      :output :stream
	      :input :stream
	      :wait nil))
       (sb-ext:process-wait *lcos-chan*))
   :name "glfw-waiting-father")
  
  (sb-thread:make-thread 
   #'(lambda ()
       (unwind-protect
           (with-open-stream (s (sb-ext:process-output *lcos-chan*))
             (loop for line = (read-line s nil nil)
                while line do
                  (format t "lcos read: ~a~%" line)
                  (finish-output)))
         (sb-ext:process-close *lcos-chan*)))
   :name "lcos-cmd-reader"))
#+nil
(lcos "toggle-stripes 1")
#+NIL
(lcos "toggle-stripes 0")
#+nil
(lcos "toggle-queue 0")
#+nil
(lcos "toggle-queue 1")
#+nil
(lcos "quit")
#+nil
(lcos "help")
#+nil
(lcos (format nil "toggle-notify-mma ~d"
	      (sb-ext:process-pid *mma-chan*)))

(defparameter *bla* 0)
(defparameter *bla-time* (get-internal-real-time))

#+nil
(get-internal-real-time)

(defparameter *mma-state* 0)
(defun reset-mma ()
  (case *mma-state*
    (0 (defparameter *mma-start-time* (get-internal-real-time)) 
       (mma "start")       
       (incf *mma-state*))
    (1 (defparameter *mma-stop-time* (get-internal-real-time))
       (mma "stop")
       (incf *mma-state*))))
#+nil
(progn
  (defparameter *exec-time* (get-internal-real-time))
  (lcos "swank-cmd")
  (sleep .1)
  (- *bla-time* *exec-time*))
;; takes 5 to 19 ms


#+nil
(loop for i below 10 collect
 (progn
   (acquisitor::acquire-stack :slices 1 :repetition 1)
   (sleep .1)
   (let ((d (- *mma-stop-time* *mma-start-time*)))
    (format t "~a~%" d)
    d)))

#+nil(reset-mma)

#+nil
(let ((a (get-internal-real-time)))
  (sleep 1)
  (- (get-internal-real-time) a))


;; echo quit > /proc/`ps aux|grep er/glfw|grep -v grep |awk '{print $2}'`/fd/0
;; echo quit > /proc/`ps aux|grep mma-cmd|grep -v grep |awk '{print $2}'`/fd/0