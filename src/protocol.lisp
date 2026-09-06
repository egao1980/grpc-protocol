(in-package #:grpc-protocol)

;;; CLOS gRPC protocol. Not JSON-RPC — see rpc-protocol.
;;; Messages are proto objects (protobuf-protocol); this layer is channel/call/stream.

(defclass grpc-backend () ())

(defclass grpc-channel ()
  ((target :initarg :target :reader grpc-channel-target)
   (backend :initarg :backend :reader grpc-channel-backend :initform nil)
   (credentials :initarg :credentials :reader grpc-channel-credentials :initform nil)
   (metadata :initarg :metadata :reader grpc-channel-metadata :initform nil)
   (compression :initarg :compression :initform nil :accessor grpc-channel-compression)
   (closed-p :initform nil :accessor grpc-channel-closed-p)))

(defmethod initialize-instance :after ((channel grpc-channel) &key)
  (unless (grpc-channel-compression channel)
    (let ((c (getf (grpc-channel-metadata channel) :compression)))
      (when c
        (setf (grpc-channel-compression channel) c)))))

(defun %metadata-with-compression (metadata compression)
  (if compression
      (list* :compression compression metadata)
      metadata))

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

(defun grpc-connect (target &key credentials metadata compression (backend *grpc-backend*))
  "Open a channel. COMPRESSION is :gzip / :deflate (http2) or NIL.
   Stashed as metadata :compression — not a gRPC header."
  (backend-grpc-connect (%ensure-backend backend) target
                        :credentials credentials
                        :metadata (%metadata-with-compression metadata compression)))

(defun grpc-call (channel method request &key timeout metadata compression)
  (when (grpc-channel-closed-p channel)
    (error 'grpc-error :status :failed-precondition :message "channel is closed"))
  (backend-grpc-call channel method request
                     :timeout timeout
                     :metadata (%metadata-with-compression metadata compression)))

(defun grpc-stream (channel method &key metadata compression)
  (when (grpc-channel-closed-p channel)
    (error 'grpc-error :status :failed-precondition :message "channel is closed"))
  (backend-grpc-stream channel method
                       :metadata (%metadata-with-compression metadata compression)))

;;; ---------------------------------------------------------------------------
;;; Server / accept loop
;;; ---------------------------------------------------------------------------

(defparameter *grpc-method-kinds*
  '(:unary :server-stream :client-stream :bidi)
  "Accepted GRPC-METHOD-HANDLER :kind values.")

(defun grpc-method-kind-p (kind)
  (and (member kind *grpc-method-kinds* :test #'eq) t))

(defclass grpc-method-handler ()
  ((method :initarg :method :reader grpc-method-handler-method)
   (kind :initarg :kind :reader grpc-method-handler-kind :initform :unary)
   (function :initarg :function :reader grpc-method-handler-function))
  (:documentation
   "One registered RPC. METHOD is \"/package.Service/Method\".
KIND is :unary, :server-stream, :client-stream, or :bidi.
FUNCTION:
  :unary          (lambda (request accept-stream) → response)
  :server-stream  (lambda (request accept-stream)) — send with GRPC-SEND
  :client-stream  (lambda (accept-stream)) — recv until :eof, then send
  :bidi           (lambda (accept-stream)) — send/recv freely"))

(defmethod initialize-instance :after ((handler grpc-method-handler) &key)
  (let ((kind (grpc-method-handler-kind handler)))
    (unless (grpc-method-kind-p kind)
      (error 'grpc-error
             :status :invalid-argument
             :message (format nil "unknown gRPC method kind ~S" kind)))))

(defun make-grpc-method-handler (method function &key (kind :unary))
  "Build a GRPC-METHOD-HANDLER. METHOD is normalized to a leading slash."
  (make-instance 'grpc-method-handler
                 :method (%serve-normalize-method method)
                 :function function
                 :kind kind))

(defun %serve-normalize-method (method)
  (let ((s (string method)))
    (if (and (plusp (length s)) (char= (char s 0) #\/))
        s
        (concatenate 'string "/" s))))

(defun find-grpc-method-handler (handlers method)
  "Look up METHOD in HANDLERS (list, hash-table, or function of method).
   Returns a GRPC-METHOD-HANDLER or NIL."
  (let ((name (%serve-normalize-method method)))
    (typecase handlers
      (null nil)
      (function
       (let ((found (funcall handlers name)))
         (cond
           ((null found) nil)
           ((typep found 'grpc-method-handler) found)
           ((functionp found)
            (make-grpc-method-handler name found :kind :unary))
           (t found))))
      (hash-table
       (or (gethash name handlers)
           (gethash method handlers)))
      (list
       (or (find name handlers
                 :key #'grpc-method-handler-method
                 :test #'string=)
           (find name handlers
                 :key #'grpc-method-handler-method
                 :test #'string-equal)))
      (t
       (error 'grpc-error
              :status :invalid-argument
              :message "handlers must be a list, hash-table, or function")))))

(defclass grpc-server ()
  ((backend :initarg :backend :reader grpc-server-backend :initform nil)
   (host :initarg :host :reader grpc-server-host :initform "127.0.0.1")
   (port :initarg :port :reader grpc-server-port :initform nil)
   (credentials :initarg :credentials :reader grpc-server-credentials :initform nil)
   (handlers :initarg :handlers :reader grpc-server-handlers :initform nil)
   (running-p :initform nil :accessor grpc-server-running-p)))

(defgeneric backend-grpc-serve (backend handlers &key host port credentials metadata)
  (:documentation
   "Accept gRPC over TLS. HANDLERS is a list of GRPC-METHOD-HANDLER,
a hash-table, or a function of method → handler.
CREDENTIALS is (:ssl :cert path :key path) — no h2c / :insecure.
Returns a GRPC-SERVER."))

(defgeneric backend-grpc-stop (server &key)
  (:documentation "Stop accepting. SERVER is a GRPC-SERVER."))

(defmethod backend-grpc-serve ((backend grpc-backend) handlers
                               &key host port credentials metadata)
  (declare (ignore handlers host port credentials metadata))
  (error 'grpc-error
         :status :unimplemented
         :message "backend-grpc-serve not implemented — load grpc-backend-http2"))

(defmethod backend-grpc-stop ((server grpc-server) &key)
  (setf (grpc-server-running-p server) nil)
  server)

(defun grpc-serve (handlers &key (host "127.0.0.1") port credentials metadata
                  (backend *grpc-backend*))
  "Start an accept loop. See BACKEND-GRPC-SERVE. TLS certs via CREDENTIALS
   or METADATA :ssl-cert / :ssl-key."
  (backend-grpc-serve (%ensure-backend backend) handlers
                      :host host
                      :port port
                      :credentials credentials
                      :metadata metadata))

(defun grpc-stop (server &key)
  (backend-grpc-stop server))
