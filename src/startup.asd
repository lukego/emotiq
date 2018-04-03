;;; -*- Mode: LISP; Syntax: COMMON-LISP -*-

(defsystem "startup"
  :version "0.0.2"
  :description "Emotiq"
  :author "Copyright (c) 2018 Emotiq AG"
  :license "MIT (see LICENSE.txt)"
  :depends-on (crypto-pairings)
  :serial t
  :in-order-to ((test-op (test-op "emotiq-test")))
  :components ((:file "startup"))
  )

