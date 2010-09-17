#.(require :ipms-ffi)
 
(defpackage :ipms
  (:use :cl :ipms-ffi))
(in-package :ipms)
 
(defun set-extern-trigger (&optional (on t))
  (if on
      (unless (= 0 (enable-extern-start))
	(error "enable-extern-start didn't return 0."))
      (unless (= 0 (disable-extern-start))
	(error "disable-extern-start didn't return 0."))))

(defun init ()
  (register-board #x0036344B00800803
		  "192.168.0.2"
		  "255.255.255.0"
		  "0.0.0.0" 
		  4001)
  (set-local-interface "192.168.0.1"
		       4001)
  (unless (= 0 (connect))
    (error "Library couldn't connect to board."))
  (load-configuration "/home/martin/linux-mma2-deprecated20100910/boardini/800803.ini")
  (set-voltage +volt-pixel+ 17.5s0)
  (set-voltage +volt-frame-f+ 17.5s0)
  (set-voltage +volt-frame-l+ 17.5s0))

(defun write-data (buf &key (pic-number 1))
  "Write a 256x256 unsigned-short buffer to the device."
  (declare ((simple-array (unsigned-byte 16) (256 256)) buf)
	   (values null &optional))
  (let ((buf1 (sb-ext:array-storage-vector buf)))
    (sb-sys:with-pinned-objects (buf)
      (write-matrix-data pic-number 3 (sb-sys:vector-sap buf1) (length buf1))))
  nil)

(defun draw (&key (r-small 0.0) (r-big 1.0) (pic-number 1))
  (declare (single-float r-small r-big)
	   (fixnum pic-number)
	   (values null &optional))
  (let* ((n 256)
	 (nh (floor n 2))
	 (1/n (/ 1.0 n))
	 (buf (make-array (list n n) 
			  :element-type '(unsigned-byte 16))))
    (declare (type (simple-array (unsigned-byte 16) 2) buf))
    (dotimes (j n)
      (dotimes (i n)
	(let* ((x (* 2.0 1/n (- i nh)))
	       (y (* 2.0 1/n (- j nh)))
	       (r (sqrt (+ (* x x) (* y y)))))
	  (setf (aref buf i j) 
		(if (< r-small r r-big) 0 #xffff)))))
    (write-data buf :pic-number pic-number)
    nil))

(defun draw-disk (&key (cx 0) (cy 0) (radius .1) (pic-number 1))
  (declare (single-float radius)
	   (fixnum cx cy pic-number) 
	   (values null &optional))
  (let* ((n 256)
	 (nh (floor n 2))
	 (1/n (/ 1.0 n))
	 (buf (make-array (list n n) 
			  :element-type '(unsigned-byte 16))))
    (declare (type (simple-array (unsigned-byte 16) 2) buf))
    (dotimes (j n)
      (dotimes (i n)
	(let* ((x (* 2.0 1/n (- i nh cx)))
	       (y (* 2.0 1/n (- j nh cy)))
	       (r (sqrt (+ (* x x) (* y y)))))
	  (setf (aref buf i j) 
		(if (< r radius) 0 #xffff)))))
    (write-data buf :pic-number pic-number)
    nil))


(defun parse-bits (value bits)
  (declare (fixnum value))
  (let ((result nil))
    (loop for (name x) in bits do
	 (when (logand value x)
	   (push name result)))
    result))
(defun parse-status-bits (value)
  (parse-bits 
   value '((peltier-on #x1000) (power-on #x4000) (start-matrix #x8000)
	   (smart-adr-on #x10000) (extern-start-en #x40000))))
(defun parse-error-bits (value)
  (parse-bits value
	      '((mirror-voltage #x01) (module-error #x02) (calibration-error #x04)
		(temperature-alert #x10) (matrix-ready-error #x20) (channel-overflow #x40)
		(ram-test-error #x100) (supply-error #x200) (config-error #x400))))
(defun status ()
  (multiple-value-bind (retval status error) (read-status)
    (unless (= 0 retval)
      (format t "read-status didn't return 0."))
    (if (not (= 0 error))
	(format t "error(s) ~a detected, status: ~a, retval: ~a~%"
		(list error (parse-error-bits error)) (parse-status-bits status) retval)
	(format t "status ~a~%" (parse-status-bits status)))))
#+nil 
(status)
(defun begin ()
  (set-power-on)
  (set-start-mma)
  (sleep 1) 
  (status))
(defun end ()
  (set-stop-mma)
  (set-power-off))

(defun select-pictures (start &key (n 1) (ready-out-needed nil))
  (dotimes (i n)
    (set-picture-sequence (+ 1 start i)
			  (if (< i (- n 1)) 0 1)
			  (if ready-out-needed 1 0))))

(defun load-concentric-circles (&key (n 12) (dr .02) (ready-out-needed nil))
  (dotimes (i n)
    (let ((r (/ (* 1.0 (1+ i)) n)))
      (format t "~a~%" `(picture ,i / ,n))
      (draw :pic-number (1+ i)
	    :r-small (- r dr)
	    :r-big (+ r dr))))
  (select-pictures 0 :n n :ready-out-needed ready-out-needed))

(defun load-disks (&key (n 12))
  (dotimes (i n)
    (let ((x (floor (* 256 (- i (floor n 2)) (/ 1.0 n)))))
      (draw-disk :cx x :cy 0 :pic-number (1+ i))))
  (select-pictures 0 :n n))

(defun load-disks2 (&key (n 12))
  (dotimes (j n)
    (dotimes (i n)
      (let ((x (floor (* 256 (- i (floor n 2)) (/ 1.0 n))))
	    (y (floor (* 256 (- j (floor n 2)) (/ 1.0 n)))))
	(draw-disk :cx x :cy y :pic-number (1+ (+ i (* n j)))))))
  (select-pictures 0 :n (* n n)))

#+nil 
(time
 (progn
   (init)
   (load-concentric-circles :n 4)
   (begin)))

(format t "~a" 'blub)

#+nil
(time (progn
	(set-stop-mma)
	(set-extern-trigger t)
	(select-pictures 2 :n 1 :ready-out-needed t)
	(begin)))

#+nil
(progn
  (select-pictures 67 :n 1 :ready-out-needed t))

#+nil
(dotimes (i 100)
  (sleep .3) 
  (select-pictures (random (* 10 10))))

#+nil
(let ((width 530s0))
 (set-extern-ready 16s0 width)
 (set-deflection-phase 16s0 width))

#+nil 
(time
 (progn
   (set-stop-mma)
   (set-extern-ready 16s0 530s0)
   (set-deflection-phase 16s0 530s0)
   (set-extern-trigger t)
   #+nil (load-concentric-circles :n 12)
   #+nil (load-disks :n 120)
   (load-disks2 :n 10)
   (begin)))
#+nil 
(progn
  (end)
  (disconnect))

(require :gui)

(gui:with-gui
  nil)