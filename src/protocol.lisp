(in-package #:grpc-protocol)

(defclass grpc-backend () ())
(defclass grpc-channel () ())

(defvar *grpc-backend* nil)

(defgeneric backend-grpc-connect (backend target &key credentials metadata))
(defgeneric backend-grpc-call (channel method request &key timeout metadata))
(defgeneric backend-grpc-stream (channel method &key metadata))
(defgeneric grpc-send (stream message &key))
(defgeneric grpc-recv (stream &key timeout))
(defgeneric grpc-close (channel-or-stream &key))

(defun %ensure-backend (&optional (backend *grpc-backend*))
  (or backend
      (error 'grpc-error :message "*grpc-backend* is nil — load grpc-backend-native")))

(defun grpc-connect (target &key credentials metadata (backend *grpc-backend*))
  (backend-grpc-connect (%ensure-backend backend) target
                        :credentials credentials :metadata metadata))

(defun grpc-call (channel method request &key timeout metadata)
  (backend-grpc-call channel method request :timeout timeout :metadata metadata))
