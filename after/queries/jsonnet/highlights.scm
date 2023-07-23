(comment) @comment
(id) @variable
(import) @include
(null) @constant.builtin
(number) @number
(string) @string

(fieldname (id) @label)
(fieldname) @string.special

"for" @repeat
(in) @keyword.operator

[
  "if"
  "then"
  "else"
] @conditional

[
  (local)
  "function"
  "assert"
] @keyword

[
  (true)
  (false)
] @boolean

[
  (dollar)
  (self)
] @variable.builtin
((id) @variable.builtin
 (#eq? @variable.builtin "std"))

[
  (binaryop_multiplicative)
  (binaryop_additive)
  (binaryop_bitshift)
  (binaryop_comparison)
  (binaryop_equality)
  (binaryop_bitand)
  (binaryop_bitxor)
  (binaryop_bitor)
  (binaryop_and)
  (binaryop_or)
  (unaryop)
] @operator

[
  "["
  "]"
  "{"
  "}"
  "("
  ")"
] @punctuation.bracket

[
  "."
  ","
  ";"
  ":"
  "::"
  ":::"
] @punctuation.delimiter

; Function declaration
(bind
  function: (id) @function
  params: (params
            (param
              identifier: (id) @parameter
            )
          )
)

; Function call
(expr
  (expr (id) @function.call)
  "("
  (args
    (named_argument
      (id) @parameter
    )
  )?
  ")"
)

(ERROR) @error
