(defun convolve2-circ (vola volb)
  (declare ((simple-array (complex my-float) 2) vola volb)
	   (values (simple-array (complex my-float) 2) &optional))
  (let* ((da (array-dimensions vola))
	 (db (array-dimensions volb))
	 (compare-ab (map 'list #'(lambda (x y) (eq x y)) da db)))
    (when (some #'null compare-ab)
      (error "convolve3-circ expects both input arrays to have the same dimensions."))
    (ift2 (s*2 (* one (reduce #'* da)) (.*2 (ft2 vola) (ft2 volb))))))

(defun convolve3-circ (vola volb)
  (declare ((simple-array (complex my-float) 3) vola volb)
	   (values (simple-array (complex my-float) 3) &optional))
  (let* ((da (array-dimensions vola))
	 (db (array-dimensions volb))
	 (compare-ab (map 'list #'(lambda (x y) (eq x y)) da db)))
    (when (some #'null compare-ab)
      (error "convolve3-circ expects both input arrays to have the same dimensions.")))
  (ift3 (.* (ft3 vola) (ft3 volb))))


(defun front (i) ;; extra size needed to accommodate kernel overlap
		 ;; there is a difference between even and odd kernels
  (declare (fixnum i)
	   (values fixnum &optional))
  (max 0
       (if (evenp i)
	   (floor i 2)
	   (1- (floor i 2)))))

;; volb is the kernel
(defun convolve3-nocrop (vola volb)
  "Convolve VOLA with VOLB. We consider VOLB as the convolution
kernel. Returns (values result vec). RESULT is an arrays that is as
big as necessary to accommodate the convolution and VEC contains the
relative coordinates to find the original sample positions of array
VOLA in RESULT."
    (declare ((simple-array (complex my-float) 3) vola volb)
	   (values (simple-array (complex my-float) 3) vec-i &optional))
  (destructuring-bind (za ya xa)
      (array-dimensions vola)
    (destructuring-bind (zb yb xb)
	(array-dimensions volb)
      (let* ((biga (make-array (list (+ za zb)
				     (+ ya yb)
				     (+ xa xb))
			       :element-type '(complex my-float)))
	     (bigb (make-array (array-dimensions biga)
			       :element-type '(complex my-float)))
	     (fzb (front zb))
	     (fyb (front yb))
	     (fxb (front xb))
	     (fza (front za))
	     (fya (front ya))
	     (fxa (front xa))
	     (start (make-vec-i :x fxb :y fyb :z fzb)))
	(do-box (k j i 0 za 0 ya 0 xa)
	  (setf (aref biga (+ k fzb) (+ j fyb) (+ i fxb))
		(aref vola k j i)))
	(do-box (k j i 0 zb 0 yb 0 xb)
	  (setf (aref bigb (+ k fza) (+ j fya) (+ i fxa))
		(aref volb k j i)))
	(values (convolve3-circ biga (fftshift3 bigb))
		start)))))

(defun convolve3 (vola volb)
  (destructuring-bind (za ya xa)
      (array-dimensions vola)
    (multiple-value-bind (conv start)
	(convolve3-nocrop vola volb)
      (let* ((result (make-array (array-dimensions vola)
				 :element-type '(complex my-float)))
	     (oz (vec-i-z start))
	     (oy (vec-i-y start))
	     (ox (vec-i-x start)))
	(do-box (k j i 0 za 0 ya 0 xa)
	  (setf (aref result k j i)
	       (aref conv (+ k oz) (+ j oy) (+ i ox))))
	result))))

#+nil
(let ((a (make-array (list 100 200 300)
		     :element-type '(complex my-float)))
      (b (make-array (list 10 200 30)
		     :element-type '(complex my-float))))
  (convolve3 a b)
  nil)
