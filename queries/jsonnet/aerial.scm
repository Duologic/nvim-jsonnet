(field
  function:
  (fieldname
    (id) @name)
    (#set! "kind" Function)) @type

(field
  (fieldname
    (id) @name)
  (_)
  (#set! "kind" Field)
) @type


(bind
  function:
  (id) @name
  (#set! "kind" Function)) @type

(bind
  (id) @name
  (#set! "kind" Variable)) @type
