;; clozure-timer.lisp -- "Proper" timers for CCL
;;
;; DM/Emotiq  01/18
;; ------------------------------------------------------------------
#|
The MIT License

Copyright (c) 2018 Emotiq AG

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
|#


(in-package :clozure-timer)

(defvar *timeout-queue*  (priq:make-lifo))
(defvar *cancel-queue*   (priq:make-lifo))
(defvar *cycle-bits*     0.0d0)
(defvar *last-check*     0)
(defvar *timeout-tree*   (maps:empty))

(defclass timer ()
  ((period   :accessor timer-period
             :initarg  :period
             :initform nil
             :documentation "True if timer should repeat periodically.")
   (t0       :accessor timer-t0
             :initarg  :t0
             :initform 0
             :documentation "Absolute universal-time when timer is set to expire.")
   (fn       :accessor timer-fn
             :initarg  :fn
             :initform (constantly nil))
   (args     :accessor timer-args
             :initarg  :args
             :initform nil)
   ))

(defun make-timer (fn &rest args)
  (make-instance 'timer
                 :fn   fn
                 :args args))

(defmethod schedule-timer ((timer timer) t0 &optional repeat)
  (setf (timer-t0 timer) t0
        (timer-period timer) repeat)
  (priq:addq *timeout-queue* timer))

(defmethod schedule-timer-relative ((timer timer) trel &optional repeat)
  (let ((t0 (+ trel (get-universal-time))))
    (setf (timer-t0 timer)     t0
          (timer-period timer) repeat)
    (priq:addq *timeout-queue* timer)))

(defmethod unschedule-timer ((timer timer))
  (priq:addq *cancel-queue* timer))


(defun #1=check-timeouts ()
  ;; read new requests
  (loop for timer = (priq:popq *timeout-queue*)
        while timer
        do
        (let* ((t0     (timer-t0 timer))
               (timers (maps:find t0 *timeout-tree*))
               (new    (cons timer (delete timer timers))))
          (setf *timeout-tree* (maps:add t0 new *timeout-tree*))))
  ;; process cancellations
  (loop for timer = (priq:popq *cancel-queue*)
        while timer
        do
        (let* ((t0     (timer-t0 timer))
               (timers (maps:find t0 *timeout-tree*)))
          (when timers
            (let ((rem (delete timer timers)))
              (setf *timeout-tree* (if rem
                                       (maps:add t0 rem *timeout-tree*)
                                     (maps:remove t0 *timeout-tree*)))))
          ))
  ;; check our current time
  (let ((now (get-universal-time)))
    (if (= now *last-check*)
        (incf now (incf *cycle-bits* 0.1d0))
      (setf *cycle-bits* 0.0d0
            *last-check* now))
    ;; fire off expired timers
    (maps:iter (lambda (t0 timer-list)
                 (when (> t0 now)
                   (return-from #1#))
                 (setf *timeout-tree* (maps:remove t0 *timeout-tree*))
                 (dolist (timer timer-list)
                   (let ((per (timer-period timer)))
                     (when per
                       (schedule-timer-relative timer per per)))
                   (apply (timer-fn timer) (timer-args timer))
                   #|
                   (multiple-value-bind (ans err)
                       (ignore-errors
                         (apply (timer-fn timer) (timer-args timer)))
                     (declare (ignore ans))
                     (when err
                       (unschedule-timer timer)))
                   |#
                   ))
               *timeout-tree*)))
      
(defun make-master-timer ()
  (mpcompat:process-run-function "Master Timer"
    '()
    (lambda ()
      (loop
       (sleep 0.1)
       (check-timeouts)))))

(defvar *master-timer* (make-master-timer))

#|
(let ((timer (make-timer (lambda () (print :Howdy!)))))
  (schedule-timer-relative timer 3 :repeat 1)
  (sleep 30)
  (unschedule-timer timer))
 |#

