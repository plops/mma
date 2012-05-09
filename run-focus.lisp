(require :focus)

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
