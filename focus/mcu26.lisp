(in-package :focus)
#+nil
(talk-zeiss *fd* *stream* "!!!")
#+nil ;; read current position
(talk-zeiss *fd* *stream* "Zi;")
#+nil
(talk-zeiss *fd* *stream* "ZA14;")