;;; Guile-RPC --- A Scheme implementation of ONC RPC.
;;; Copyright (C) 2007  Ludovic Court�s <ludovic.courtes@laas.fr>
;;;
;;; Guile-RPC is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Lesser General Public
;;; License as published by the Free Software Foundation; either
;;; version 2.1 of the License, or (at your option) any later version.
;;;
;;; Guile-RPC is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Lesser General Public License for more details.
;;;
;;; You should have received a copy of the GNU Lesser General Public
;;; License along with Guile-RPC; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

(define-module (rpc xdr types)
  :autoload   (srfi srfi-1) (find)
  :autoload   (srfi srfi-34) (raise)
  :use-module (srfi srfi-35)
  :use-module (rpc xdr)
  :use-module (r6rs bytevector)
  :use-module (r6rs i/o ports)
  :export (make-xdr-fixed-length-opaque-array
           make-xdr-variable-length-opaque-array
           xdr-variable-length-opaque-array
           make-xdr-enumeration
           xdr-boolean
           xdr-integer
           xdr-unsigned-integer
           xdr-hyper-integer xdr-unsigned-hyper-integer
           xdr-float xdr-double
           xdr-string make-xdr-string
           xdr-void %void

           &xdr-enumeration-error xdr-enumeration-error?
           xdr-enumeration-error:enumeration-alist
           xdr-enumeration-error:value))

;;; Author: Ludovic Court�s <ludovic.courtes@laas.fr>
;;;
;;; Commentary:
;;;
;;; An implementation of some of the types defined in RFC 4506.  The missing
;;; types (e.g., floats and quadruple-precision floats) are due to the lack
;;; of a proper handling in the R6RS bytevector API.
;;;
;;; Code:


;;;
;;; Additional error conditions.
;;;

(define-condition-type &xdr-enumeration-error &xdr-type-error
  xdr-enumeration-error?
  (enumeration-alist xdr-enumeration-error:enumeration-alist)
  (value             xdr-enumeration-error:value))



;;;
;;; Actual base types.
;;;

(define xdr-integer
  ;; Section 4.1.
  (make-xdr-basic-type 'int32 4
                       (lambda (value)
                         (and (integer? value)
                              (>= -2147483648)
                              (< 2147483648)))
                       (lambda (type value bv index)
                         (bytevector-s32-set! bv index value
                                              %xdr-endianness))
                       (lambda (type port)
                         (bytevector-s32-ref (get-bytevector-n port 4)
                                             0 %xdr-endianness))
                       (lambda (type count port)
                         (let ((bv (get-bytevector-n port (* 4 count))))
                           (apply vector
                                  (bytevector->sint-list bv %xdr-endianness
                                                         4))))))

(define xdr-unsigned-integer
  ;; Section 4.2.
  (make-xdr-basic-type 'uint32 4
                       (lambda (value)
                         (and (integer? value)
                              (>= value 0)
                              (<= value 4294967296)))
                       (lambda (type value bv index)
                         (bytevector-u32-set! bv index value
                                              %xdr-endianness))
                       (lambda (type port)
                         (bytevector-u32-ref (get-bytevector-n port 4)
                                             0 %xdr-endianness))
                       (lambda (type count port)
                         (let ((bv (get-bytevector-n port (* 4 count))))
                           (apply vector
                                  (bytevector->uint-list bv %xdr-endianness
                                                         4))))))

(define (make-xdr-enumeration name enum-alist)
  ;; Section 4.3.
  (define (enum-error type value)
    (raise (condition
            (&xdr-enumeration-error (type type)
                                    (value value)
                                    (enumeration-alist enum-alist)))))

  (define (enum-symbol type value)
    (let ((sym (find (lambda (pair)
                        (= value (cdr pair)))
                     enum-alist)))
      (if (not sym)
          (enum-error type value)
          (car sym))))

  (define (decode-enum type port)
    (let* ((bv (get-bytevector-n port 4)))
      (enum-symbol type (bytevector-u32-ref bv 0 %xdr-endianness))))

  (make-xdr-basic-type (symbol-append 'enum- name) 4
                       (lambda (value)
                         (and (symbol? value)
                              (assq value enum-alist)))
                       (lambda (type value bv index)
                         (let ((value (cdr (assq value enum-alist))))
                           (bytevector-u32-set! bv index value
                                                %xdr-endianness)))
                       decode-enum
                       (lambda (type count port)
                         (let ((bv (get-bytevector-n port (* 4 count))))
                           (apply vector
                                  (map (lambda (value)
                                         (enum-symbol type value))
                                       (bytevector->uint-list bv
                                                              %xdr-endianness
                                                              4)))))))

(define xdr-boolean
  ;; Section 4.4.
  (make-xdr-enumeration 'bool '((FALSE . 0) (TRUE . 1))))

(define xdr-hyper-integer
  ;; Section 4.5.
  (make-xdr-basic-type 'int64 8
                       integer?
                       (lambda (type value bv index)
                         (bytevector-s64-set! bv index value
                                              %xdr-endianness))
                       (lambda (type port)
                         (bytevector-s64-ref (get-bytevector-n port 8)
                                             0 %xdr-endianness))
                       (lambda (type count port)
                         (let ((bv (get-bytevector-n port (* 8 count))))
                           (apply vector
                                  (bytevector->sint-list bv %xdr-endianness
                                                         8))))))

(define xdr-unsigned-hyper-integer
  ;; Section 4.5.
  (make-xdr-basic-type 'uint64 8
                       (lambda (value)
                         (and (integer? value)
                              (>= value 0)))
                       (lambda (type value bv index)
                         (bytevector-u64-set! bv index value
                                              %xdr-endianness))
                       (lambda (type port)
                         (bytevector-u64-ref (get-bytevector-n port 8)
                                             0 %xdr-endianness))
                       (lambda (type count port)
                         (let ((bv (get-bytevector-n port (* 8 count))))
                           (apply vector
                                  (bytevector->uint-list bv %xdr-endianness
                                                         8))))))

(define xdr-float
  ;; Single-precision floating point (Section 4.6).
  (make-xdr-basic-type 'float 4
                       (lambda (value)
                         (and (number? value)
                              (inexact? value)))
                       (lambda (type value bv index)
                         (bytevector-ieee-single-set! bv index value
                                                      %xdr-endianness))
                       (lambda (type port)
                         (bytevector-ieee-single-ref
                          (get-bytevector-n port 4) 0 %xdr-endianness))))

(define xdr-double
  ;; Double-precision floating point (Section 4.7).
  (make-xdr-basic-type 'double 8
                       (lambda (value)
                         (and (number? value)
                              (inexact? value)))
                       (lambda (type value bv index)
                         (bytevector-ieee-double-set! bv index value
                                                      %xdr-endianness))
                       (lambda (type port)
                         (bytevector-ieee-double-ref
                          (get-bytevector-n port 8) 0 %xdr-endianness))))

(define xdr-single-opaque
  ;; The XDR `opaque' type cannot be used on its own.
  (make-xdr-basic-type 'opaque 1
                       (lambda (value)
                         (and (integer? value)
                              (>= value 0)
                              (<= value 255)))
                       (lambda (type value bv index)
                         (bytevector-u8-set! bv index value))
                       (lambda (type port)
                         (let ((c (get-u8 port)))
                           (if (eof-object? c)
                               (error "input shallow" c) ;; FIXME: raise
                               c)))
                       (lambda (type count port)
                         (let ((bv (get-bytevector-n port count)))
                           (apply vector (bytevector->u8-list bv))))))

(define (make-xdr-fixed-length-opaque-array size)
  ;; Section 4.9.
  (make-xdr-struct-type (make-list size xdr-single-opaque)))

(define (make-xdr-variable-length-opaque-array limit)
  ;; Section 4.10.
  (make-xdr-vector-type xdr-single-opaque limit))

(define xdr-variable-length-opaque-array
  ;; Section 4.10.
  (make-xdr-vector-type xdr-single-opaque #f))

;; Section 4.11.
;; XXX: Strings normally require zeroed padding.
(define make-xdr-string make-xdr-variable-length-opaque-array)
(define xdr-string      xdr-variable-length-opaque-array)

(define %void
  ;; The `void' value, obtained when deserializing a `void' object.
  (list 'void))

(define xdr-void
  ;; Section 4.16.
  (make-xdr-basic-type 'void 0
                       (lambda (value) #t)
                       (lambda (type value bv index) #t)
                       (lambda (type port) %void)))


;;; types.scm ends here

;;; Local Variables:
;;; coding: latin-1
;;; End:

;;; arch-tag: 0f94db34-2f49-4830-b2da-14bf08ff06cb
