(in-package #:grpc-protocol/tests)

(deftest no-backend-signals
  (let ((grpc-protocol:*grpc-backend* nil))
    (ok (signals (grpc-protocol:grpc-connect "localhost:50051")
                 'grpc-protocol:grpc-error))))
