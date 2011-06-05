(in-package :andor3)

(defparameter *andor3-library* 
  (load-shared-object "/usr/local/lib/libatcore.so"))

(define-alien-type handle int)
(define-alien-type at_bool int)
(define-alien-type at_64 long-long)
(define-alien-type wchar_t unsigned-int) ;; 32bit first byte contains ascii
(define-alien-type at_wc wchar_t)

(eval-when (:compile-toplevel)
 (defun split-by-one-hyphen (string)
   "Returns a list of substrings of string divided by ONE hyphen
each.  Note: Two consecutive hyphens will be seen as if there were an
empty string between them."
   (loop for i = 0 then (1+ j)
      as j = (position #\- string :start i)
      collect (subseq string i j)
      while j))

 (defun lisp-to-camel-case (name)
   "Convert initialise-library into AT_InitialiseLibrary."
   (declare (type simple-string name))
   (let* ((words (split-by-one-hyphen name))
	  (cwords (mapcar #'string-capitalize words)))
     (push "AT_" cwords)
     (format nil "~{~a~}" cwords)))

 )

#+nil
(split-by-one-hyphen "initialise-library")
#+nil
(lisp-to-camel-case "initialise-library")


(defmacro x (name &key (default t) params)
  "Short cut to define a function according to a standard pattern for
the Andor SDK version 3. If DEFAULT is true, return int, first
argument is handle and second argument is wchar_t string."
  `(define-alien-routine (,(lisp-to-camel-case (symbol-name name)) 
			   ,(intern (concatenate 'string "%" (symbol-name name))))
       int
     ,@(when default '((handle handle)
		       (feature (* wchar_t))))
     ,@params))

;; wchar_t is 32bit on my x86_64

(x initialise-library :default nil)
(x finalise-library :default nil)
(x open 
   :default nil
   :params ((camera-index int)
	    (handle handle :out)))
(x close
   :default nil
   :params ((camera-index int)))

#+nil
(alien-sap ;; callback
 (sb-alien::alien-lambda int ((h handle)
			 (feature (* wchar_t))
			 (context (* int))) ...))

(x register-feature-callback
   :params ((callback (* int))
	    (context (* int))))
(x unregister-feature-callback
   :params ((callback (* int))
	    (context (* int))))

(x is-implemented :params ((implemented at_bool :out)))
(x is-readable :params ((readable at_bool :out)))
(x is-writable :params ((writable at_bool :out)))
(x is-read-only :params ((read-only at_bool :out)))

(x set-int :params ((value at_64)))
(x get-int :params ((value at_64 :out)))
(x get-int-max :params ((max-value at_64 :out)))
(x get-int-min :params ((min-value at_64 :out)))

(x set-float :params ((value double)))
(x get-float :params ((value double :out)))
(x get-float-max :params ((max-value double :out)))
(x get-float-min :params ((min-value double :out)))

(x set-bool :params ((value at_bool)))
(x get-bool :params ((value at_bool :out)))

(x set-enumerated :params ((value int)))
(x get-enumerated :params ((value int :out)))
(x get-enumerated-count :params ((count int :out)))
(x set-enumerated-string :params ((string (* at_wc))))
(x get-enumerated-string :params ((string (* at_wc))
				  (length int)))
(x is-enumerated-index-available :params ((index int)
					  (available at_bool :out)))
(x is-enumerated-index-implemented :params ((index int)
					    (implemented at_bool :out)))

(x set-enum-index :params ((value int)))
(x set-enum-string :params ((string (* at_wc))))
(x get-enum-index :params ((value int :out)))
(x get-enum-count :params ((count int :out)))
(x is-enum-index-available :params ((index int)
				    (available at_bool :out)))
(x is-enum-index-implemented :params ((index int)
				      (implemented at_bool :out)))
(x get-enum-string-by-index :params ((index int)
				     (string (* at_wc))
				     (length int)))

(x at_command)

(x set-string :params ((string (* at_wc))))
(x get-string :params ((string (* at_wc))
		       (length int)))
(x get-string-max-length :params ((max-string-length int :out)))

(x queue-buffer :params ((ptr (* unsigned-char))
			 (bytes int)))
(x wait-buffer :params ((ptr unsigned-long :out) ;; it returns a
						 ;; pointer to an
						 ;; address
			(bytes int :out)
			(timeout unsigned-int)))

(x flush :default nil :params ((handle handle)))
 
;; cat /usr/local/include/atcore.h |grep define|grep -v "^#if"|grep -v AT_EXP |grep -v ATCORE|grep AT_ERR|awk '{print "("$3+1-1 " '\''" $2")"}'
(defun lookup-error (err)
  (ecase err
    (1 'AT_ERR_NOTINITIALISED)
    (2 'AT_ERR_NOTIMPLEMENTED)
    (3 'AT_ERR_READONLY)
    (4 'AT_ERR_NOTREADABLE)
    (5 'AT_ERR_NOTWRITABLE)
    (6 'AT_ERR_OUTOFRANGE)
    (7 'AT_ERR_INDEXNOTAVAILABLE)
    (8 'AT_ERR_INDEXNOTIMPLEMENTED)
    (9 'AT_ERR_EXCEEDEDMAXSTRINGLENGTH)
    (10 'AT_ERR_CONNECTION)
    (11 'AT_ERR_NODATA)
    (12 'AT_ERR_INVALIDHANDLE)
    (13 'AT_ERR_TIMEDOUT)
    (14 'AT_ERR_BUFFERFULL)
    (15 'AT_ERR_INVALIDSIZE)
    (16 'AT_ERR_INVALIDALIGNMENT)
    (17 'AT_ERR_COMM)
    (18 'AT_ERR_STRINGNOTAVAILABLE)
    (19 'AT_ERR_STRINGNOTIMPLEMENTED)
    (20 'AT_ERR_NULL_FEATURE)
    (21 'AT_ERR_NULL_HANDLE)
    (22 'AT_ERR_NULL_IMPLEMENTED_VAR)
    (23 'AT_ERR_NULL_READABLE_VAR)
    (24 'AT_ERR_NULL_READONLY_VAR)
    (25 'AT_ERR_NULL_WRITABLE_VAR)
    (26 'AT_ERR_NULL_MINVALUE)
    (27 'AT_ERR_NULL_MAXVALUE)
    (28 'AT_ERR_NULL_VALUE)
    (29 'AT_ERR_NULL_STRING)
    (30 'AT_ERR_NULL_COUNT_VAR)
    (31 'AT_ERR_NULL_ISAVAILABLE_VAR)
    (32 'AT_ERR_NULL_MAXSTRINGLENGTH)
    (33 'AT_ERR_NULL_EVCALLBACK)
    (34 'AT_ERR_NULL_QUEUE_PTR)
    (35 'AT_ERR_NULL_WAIT_PTR)
    (36 'AT_ERR_NULL_PTRSIZE)
    (37 'AT_ERR_NOMEMORY)
    (100 'AT_ERR_HARDWARE_OVERFLOW)))
 
#+nil
(lookup-error 34)
