(asdf:defsystem gui
  :depends-on (:cl-opengl :cl-glut :cl-glu :alexandria :vector :lens :cxml)
  :components ((:module "gui"
			:serial t
			:components
			((:file "packages")
			 (:file "draw")
			 (:file "draw-grating")
			 (:file "gui")
			 (:file "svg-font")))))