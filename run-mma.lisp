(setf asdf:*central-registry* (list "~/stage/mma/"))
(eval-when (:compile-toplevel :execute :load-toplevel)
  (require :mma))

(in-package :mma)
;; ifconfig eth1 192.168.0.1



#+nil
(time (init)) ;; takes 6.3s
#+nil
(uninit)

#+nil
(register-board #x0036344B00800803
		"192.168.0.2"
		"255.255.255.0"
		"0.0.0.0" 
		4001)

#+nil
(set-local-interface "192.168.0.1"
		     4001)


#+nil
(connect)

#+nil
(reset)


#+nil
(status)
	  
#+nil
(load-configuration "/home/grml/stage/mma-essentials-0209/800803.ini")



#+nil
(load-calibration-data 
 "/home/grml/stage/mma-essentials-0209/VC2481_15_67_2011-02-01_0-250nm_Rand7_Typ1.cal")

(check (set-voltage +volt-frame-f+ 15.0s0))

(check (set-voltage +volt-frame-l+ 15.0s0))


(defparameter *width* (+ 188s0 10000s0))

#+nil
(set-extern-ready (+ 20s0 0s0)
		  (- *width* 20s0)) ;; should start 20us later than deflection


#+nil
(set-deflection-phase 0s0 *width*)

#+nil
(mma::set-cycle-time (+ .01 (* 2 *width*)))
#+nil
(mma::set-cycle-time 33s0)

#+nil
(mma::enable-extern-start)

#+nil
(mma:set-nominal-deflection-nm 133s0)


#+nil
(let ((cmd "STM#DBE " ))
  (ipms-ffi::service-command "SEND#SRV" cmd (length cmd)))

#+nil
(mma::get-mma-temperature)
#+nil2
(mma::set-mma-temperature 22s0)
#+nil
(mma::switch-peltier-on)
#+nil
(mma::switch-peltier-off)


#+nil
(set-power-on)

#+nil
(progn ;; write a picture
 (let* ((n 256)
	(nh (floor n 2))
	(buf (make-array (list n n) :element-type '(unsigned-byte 16)
			 :initial-element 0))
	(buf1 (sb-ext:array-storage-vector buf)))
   (dotimes (i n)
     (dotimes (j n)
       (let* ((x (* (- i nh) (/ 2s0 n)))
	      (y (* (- j nh) (/ 2s0 n)))
	      (r (sqrt (+ (* x x) (* y y)))))
	 (setf (aref buf j i)
	      (if (< r .9)
		  4095
		  0)))))
   (sb-sys:with-pinned-objects (buf)
     (write-matrix-data 1 3 (sb-sys:vector-sap buf1) 
			(* n n)))))
#+nil
(mma::set-picture-sequence 1 0 1)
#+nil
(mma::set-picture-sequence 1 1 1)

#+nil
(mma::set-start-mma)
#+nil
(status)
#+nil
(multiple-value-bind (a b c)
    (read-status)
  (format nil "#x~x%d" b))
#+nil
(mma::set-stop-mma)
#+nil
(mma::disable-extern-start)
#+nil
(mma::set-extern-trigger t)

#+nil
(mma::set-start-mma)


#+nil
(mma:select-pictures 0 :n 1 :ready-out-needed t)

#+nil
(let* ((n 256)
       (m (make-array (list n n) :element-type '(unsigned-byte 12))))
  (dotimes (j n)
    (dotimes (i n)
      (setf (aref m j i) (*  (* (mod i 2) #+nil (mod j 2)) 4095))))
  (mma:draw-array-cal m :pic-number 1)
  nil)

#+nil
(mma::set-stop-mma)
#+nil
(mma::set-power-off)
#+nil
(disconnect)

