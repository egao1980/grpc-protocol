(defpackage #:grpc-protocol
  (:use #:cl)
  (:nicknames #:stack-grpc)
  (:export #:grpc-error
           #:grpc-error-message
           #:grpc-error-status
           #:grpc-error-details
           #:grpc-backend
           #:grpc-channel
           #:grpc-call
           #:grpc-stream
           #:*grpc-backend*
           #:grpc-channel-target
           #:grpc-channel-backend
           #:grpc-channel-credentials
           #:grpc-channel-metadata
           #:grpc-channel-closed-p
           #:grpc-call-channel
           #:grpc-call-method
           #:grpc-stream-channel
           #:grpc-stream-method
           #:grpc-stream-closed-p
           #:backend-grpc-connect
           #:backend-grpc-call
           #:backend-grpc-stream
           #:grpc-send
           #:grpc-recv
           #:grpc-close
           #:grpc-connect))

(in-package #:grpc-protocol)
