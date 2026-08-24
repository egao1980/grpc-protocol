(in-package #:grpc-protocol/tests)

(defclass mock-backend (grpc-protocol:grpc-backend) ())

(defclass mock-channel (grpc-protocol:grpc-channel) ())

(defclass mock-stream (grpc-protocol:grpc-stream)
  ((inbox :initarg :inbox :initform nil :accessor mock-inbox)
   (outbox :initform nil :accessor mock-outbox)))

(defmethod grpc-protocol:backend-grpc-connect ((backend mock-backend) target
                                               &key credentials metadata)
  (make-instance 'mock-channel
                 :target target
                 :backend backend
                 :credentials credentials
                 :metadata metadata))

(defmethod grpc-protocol:backend-grpc-call ((channel mock-channel) method request
                                            &key timeout metadata)
  (declare (ignore timeout))
  (list :ok method request
        (grpc-protocol:grpc-channel-target channel)
        (getf metadata :response-class)))

(defmethod grpc-protocol:backend-grpc-stream ((channel mock-channel) method
                                              &key metadata)
  (make-instance 'mock-stream
                 :channel channel
                 :method method
                 :inbox (copy-list (getf metadata :inbox))))

(defmethod grpc-protocol:grpc-send ((stream mock-stream) message &key)
  (push message (mock-outbox stream))
  message)

(defmethod grpc-protocol:grpc-recv ((stream mock-stream) &key timeout)
  (declare (ignore timeout))
  (let ((next (pop (mock-inbox stream))))
    (or next :eof)))

(defun with-mock (fn)
  (let ((grpc-protocol:*grpc-backend* (make-instance 'mock-backend)))
    (funcall fn)))

(deftest call-class-exists
  (ok (find-class 'grpc-protocol:grpc-call)))

(deftest bare-channel-unimplemented
  (let ((ch (make-instance 'grpc-protocol:grpc-channel :target "localhost:1")))
    (ok (signals (grpc-protocol:grpc-call ch "/pkg.Svc/Ping" #())
                 'grpc-protocol:grpc-error))))

(deftest no-backend-signals
  (let ((grpc-protocol:*grpc-backend* nil))
    (ok (signals (grpc-protocol:grpc-connect "localhost:50051")
                 'grpc-protocol:grpc-error))))

(deftest base-backend-unimplemented
  (let ((grpc-protocol:*grpc-backend* (make-instance 'grpc-protocol:grpc-backend)))
    (ok (signals (grpc-protocol:grpc-connect "localhost:50051")
                 'grpc-protocol:grpc-error))))

(deftest connect-call-roundtrip
  (with-mock
    (lambda ()
      (let ((ch (grpc-protocol:grpc-connect "localhost:1"
                                            :credentials :insecure
                                            :metadata '(:a 1))))
        (ok (typep ch 'grpc-protocol:grpc-channel))
        (ok (equal "localhost:1" (grpc-protocol:grpc-channel-target ch)))
        (ok (eq :insecure (grpc-protocol:grpc-channel-credentials ch)))
        (let ((result (grpc-protocol:grpc-call ch "/pkg.Svc/Ping" #(1 2)
                                               :metadata '(:response-class foo))))
          (ok (equalp (list :ok "/pkg.Svc/Ping" #(1 2) "localhost:1" 'foo)
                      result)))
        (grpc-protocol:grpc-close ch)
        (ok (grpc-protocol:grpc-channel-closed-p ch))
        (ok (signals (grpc-protocol:grpc-call ch "/pkg.Svc/Ping" #())
                     'grpc-protocol:grpc-error))))))

(deftest stream-send-recv
  (with-mock
    (lambda ()
      (let* ((ch (grpc-protocol:grpc-connect "localhost:1"))
             (st (grpc-protocol:grpc-stream ch "/pkg.Svc/Chat"
                                            :metadata '(:inbox (a b)))))
        (ok (typep st 'grpc-protocol:grpc-stream))
        (ok (eq ch (grpc-protocol:grpc-stream-channel st)))
        (ok (equal "/pkg.Svc/Chat" (grpc-protocol:grpc-stream-method st)))
        (ok (eq 'a (grpc-protocol:grpc-recv st)))
        (ok (eq 'b (grpc-protocol:grpc-recv st)))
        (ok (eq :eof (grpc-protocol:grpc-recv st)))
        (ok (eq 'x (grpc-protocol:grpc-send st 'x)))
        (ok (equal '(x) (mock-outbox st)))
        (grpc-protocol:grpc-close st)
        (ok (grpc-protocol:grpc-stream-closed-p st))))))

(deftest default-stream-ops-unimplemented
  (let ((st (make-instance 'grpc-protocol:grpc-stream
                           :channel nil :method "/x")))
    (ok (signals (grpc-protocol:grpc-send st 1) 'grpc-protocol:grpc-error))
    (ok (signals (grpc-protocol:grpc-recv st) 'grpc-protocol:grpc-error))))

(deftest error-slots
  (let ((c (make-condition 'grpc-protocol:grpc-error
                           :status :unavailable
                           :message "down"
                           :details '(:retry 1))))
    (ok (eq :unavailable (grpc-protocol:grpc-error-status c)))
    (ok (equal "down" (grpc-protocol:grpc-error-message c)))
    (ok (equal '(:retry 1) (grpc-protocol:grpc-error-details c)))))
