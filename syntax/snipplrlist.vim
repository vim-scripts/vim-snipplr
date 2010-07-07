syn match snipplrComment "^#.*"
syn match snipplrID '^\s*\d\+\s'
syn region snipplrTag start=/\[/ end=/\]/ contains=snipplrFlagM,snipplrFlagF,snipplrOther
syn match snipplrOther "\<\w\+\>" contained
syn match snipplrFlagM "\<M\>" contained
syn match snipplrFlagF "\<F\>" contained

hi def link snipplrComment Comment
hi def link snipplrID Number
hi def link snipplrFlagM Identifier
hi def link snipplrFlagF Keyword
hi def link snipplrOther Function

