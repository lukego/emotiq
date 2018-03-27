(in-package "CL-USER")
(load-all-patches)
(load "~/quicklisp/setup.lisp")
(ql:quickload :emotiq)
(ql:quickload :crypto-pairings)
(ql:quickload :core-crypto)

(defun main ()
  (pbc-interface:init-pairing)
  (pbc:make-key-pair :dave)
  (let ((signed (pbc:sign-message :hello)))
    (if (pbc:check-message signed)
        (format *standard-output* "~%OK~%")
      (format *standard-output* "~%NOT OK~%"))))

(deliver 'main "emotiq" 0 :multiprocessing t :console t)
