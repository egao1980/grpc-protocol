(in-package #:grpc-protocol)

;;; Status keywords match grpc-status-code without the :grpc-status- prefix.
;;; :ok :cancelled :unknown :invalid-argument :deadline-exceeded :not-found
;;; :already-exists :permission-denied :resource-exhausted :failed-precondition
;;; :aborted :out-of-range :unimplemented :internal :unavailable :data-loss
;;; :unauthenticated

(define-condition grpc-error (error)
  ((message :initarg :message :reader grpc-error-message :initform nil)
   (status :initarg :status :reader grpc-error-status :initform nil)
   (details :initarg :details :reader grpc-error-details :initform nil))
  (:report (lambda (c s)
             (format s "grpc error~@[ ~a~]~@[: ~a~]"
                     (grpc-error-status c) (grpc-error-message c)))))
