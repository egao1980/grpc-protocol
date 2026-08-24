(in-package #:grpc-protocol)

;;; CLOS gRPC protocol. Not JSON-RPC — see rpc-protocol.
;;; Messages are proto objects (protobuf-protocol); this layer is channel/call/stream.

(defclass grpc-backend () ())

(defclass grpc-channel ()
  ((target :initarg :target :reader grpc-channel-target)
   (backend :initarg :backend :reader grpc-channel-backend :initform nil)
   (credentials :initarg :credentials :reader grpc-channel-credentials :initform nil)
   (metadata :initarg :metadata :reader grpc-channel-metadata :initform nil)
   (closed-p :initform nil :accessor grpc-channel-closed-p)))

(defclass grpc-call ()
  ((channel :initarg :channel :reader grpc-call-channel)
   (method :initarg :method :reader grpc-call-method)))

(defclass grpc-stream ()
  ((channel :initarg :channel :reader grpc-stream-channel)
   (method :initarg :method :reader grpc-stream-method)
   (closed-p :initform nil :accessor grpc-stream-closed-p)))

(defvar *grpc-backend* nil
  "Current gRPC backend. Load grpc-backend-native to bind.")

(defgeneric backend-grpc-connect (backend target &key credentials metadata)
  (:documentation "Open a channel to TARGET (host:port). CREDENTIALS is
NIL / :insecure or (:ssl :pem-root-certs …)."))

(defgeneric backend-grpc-call (channel method request &key timeout metadata)
  (:documentation "Unary RPC. METHOD is \"/package.Service/Method\".
REQUEST is a proto message or octets. Returns response octets or a proto
message when METADATA includes :response-class."))

(defgeneric backend-grpc-stream (channel method &key metadata)
  (:documentation "Open a client/server/bidi stream for METHOD."))

(defgeneric grpc-send (stream message &key)
  (:documentation "Send MESSAGE on STREAM."))

(defgeneric grpc-recv (stream &key timeout)
  (:documentation "Receive one message from STREAM. :eof when the peer is done."))

(defgeneric grpc-close (channel-or-stream &key)
  (:documentation "Release CHANNEL or STREAM."))

(defmethod backend-grpc-connect ((backend grpc-backend) target &key credentials metadata)
  (declare (ignore target credentials metadata))
  (error 'grpc-error
         :status :unimplemented
         :message "backend-grpc-connect not implemented — load grpc-backend-native"))

(defmethod backend-grpc-call ((channel grpc-channel) method request &key timeout metadata)
  (declare (ignore method request timeout metadata))
  (error 'grpc-error
         :status :unimplemented
         :message "backend-grpc-call not implemented"))

(defmethod backend-grpc-stream ((channel grpc-channel) method &key metadata)
  (declare (ignore method metadata))
  (error 'grpc-error
         :status :unimplemented
         :message "backend-grpc-stream not implemented"))

(defmethod grpc-send ((stream grpc-stream) message &key)
  (declare (ignore message))
  (error 'grpc-error
         :status :unimplemented
         :message "grpc-send not implemented"))

(defmethod grpc-recv ((stream grpc-stream) &key timeout)
  (declare (ignore timeout))
  (error 'grpc-error
         :status :unimplemented
         :message "grpc-recv not implemented"))

(defmethod grpc-close ((channel grpc-channel) &key)
  (setf (grpc-channel-closed-p channel) t)
  channel)

(defmethod grpc-close ((stream grpc-stream) &key)
  (setf (grpc-stream-closed-p stream) t)
  stream)

(defun %ensure-backend (&optional (backend *grpc-backend*))
  (or backend
      (error 'grpc-error
             :status :internal
             :message "*grpc-backend* is nil — load grpc-backend-native")))

(defun grpc-connect (target &key credentials metadata (backend *grpc-backend*))
  (backend-grpc-connect (%ensure-backend backend) target
                        :credentials credentials :metadata metadata))

(defun grpc-call (channel method request &key timeout metadata)
  (when (grpc-channel-closed-p channel)
    (error 'grpc-error :status :failed-precondition :message "channel is closed"))
  (backend-grpc-call channel method request :timeout timeout :metadata metadata))

(defun grpc-stream (channel method &key metadata)
  (when (grpc-channel-closed-p channel)
    (error 'grpc-error :status :failed-precondition :message "channel is closed"))
  (backend-grpc-stream channel method :metadata metadata))
