(in-package #:grpc-protocol)

(define-condition grpc-error (error)
  ((message :initarg :message :reader grpc-error-message :initform nil)
   (status :initarg :status :reader grpc-error-status :initform nil))
  (:report (lambda (c s)
             (format s "grpc error~@[ ~a~]~@[: ~a~]"
                     (grpc-error-status c) (grpc-error-message c)))))
