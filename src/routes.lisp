;;;; colorize.lisp
;;;;
;;;; This file is part of the restas-colorize library, released under Lisp-LGPL.
;;;; See file COPYING for details.
;;;;
;;;; Author: Moskvitin Andrey <archimag@gmail.com>

(in-package #:restas.colorize)

(defun note-plist/short (note)
  (list :href (restas:genurl 'view-note :id (note-id note))
        :date (local-time:format-timestring nil (note-date note))
        :title (note-title note)
        :author (note-author note)))

(defun note-plist (note)
  (list* :title (note-title note)
         :code (note-code note)
         :lang (note-lang note)
         (note-plist/short note)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; routes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(restas:define-route main ("")
  (restas:redirect 'list-notes))

(restas:define-route list-notes ("all")
  (aglorp:with-storage *storage*
    (let* ((total-count (aglorp:count-objects 'note))
           (start (min (max (or (ignore-errors (parse-integer (hunchentoot:get-parameter "start")))
                                1)
                            1)
                       total-count)))
      (list :title "All notes"
            :notes (iter (for note in (aglorp:read-objects 'note
                                                           :limit *max-on-page*
                                                           :offset (1- start) ))
                         (collect (note-plist/short note)))
            :first start
            :total-count total-count
            :href-before (if (< (+ (1- start) *max-on-page*)
                                total-count)
                             (format nil
                                     "~A?start=~A"
                                     (restas:genurl 'list-notes)
                                     (+ start *max-on-page*)))
            :href-after (if (> start 1)
                            (format nil
                                    "~A?start=~A"
                                    (restas:genurl 'list-notes)
                                    (max (- start *max-on-page*) 1)))))))

(restas:define-route view-note (":id"
                                :parse-vars (list :id #'parse-integer))
  (aglorp:with-storage *storage*
    (note-plist (aglorp:one-object 'note :note-id id))))

(restas:define-route create-note ("create")
  (list :title "Создать"))

(restas:define-route preview-note ("create"
                                   :method :post
                                   :requirement #'(lambda () (hunchentoot:post-parameter "preview")))
  (list :title (hunchentoot:post-parameter "title")
        :author (colorize-user)
        :code (hunchentoot:post-parameter "code")
        :lang (hunchentoot:post-parameter "lang")))


(restas:define-route save-note ("create"
                                :method :post
                                :requirement #'(lambda () (hunchentoot:post-parameter "save")))
  (let ((author (colorize-user)))
    (if author
        (restas:redirect 'view-note
                         :id (aglorp:with-storage *storage*
                               (note-id (aglorp:persist-object
                                         (make-instance  'note
                                                         :code (hunchentoot:post-parameter "code")
                                                         :author author
                                                         :lang (hunchentoot:post-parameter "lang")
                                                         :title (hunchentoot:post-parameter "title"))))))
        hunchentoot:+http-forbidden+)))
