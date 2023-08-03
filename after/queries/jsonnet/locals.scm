(parenthesis) @scope
(anonymous_function) @scope
(object) @scope
(field) @scope
(local_bind) @scope

(field
  function: (fieldname (id)  @definition.function)
  (#set! "definition.function.scope" "parent")
)

(bind function: (id)  @definition.function)

(param (id) @definition.parameter)

(id) @reference
