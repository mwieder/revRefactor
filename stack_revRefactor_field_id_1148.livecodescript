Script "stack_revRefactor_field_id_1148"

/*
# Name: field "fldUndeclared" of card "Undeclared" of stack "revRefactor"
# ID: field id 1148 of card id 1141 of stack "revRefactor"
*/


on mouseUp
   local tLineNumber
   
   put word 2 of the selectedtext into tLineNumber
   dispatch "goLine" to group "Editor" of stack refactorSEName() with tLineNumber, true
end mouseUp

on mouseDoubleUp
   local tVariableName
   
   put word 3 of the selectedtext into tVariableName
   declareLocalVariable tVariableName
   mouseUp
end mouseDoubleUp
