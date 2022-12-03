Script "stack_revRefactor_field_id_1579"

/*
# Name: field "fldOrphanList" of card "RenamedVariables" of stack "revRefactor"
# ID: field id 1579 of card id 1578 of stack "revRefactor"
*/


on mouseUp
   local tLineNumber
   
   put word 1 of the selectedtext into tLineNumber
   dispatch "goLine" to group "Editor" of stack refactorSEName() with tLineNumber, true
end mouseUp

on mouseMove
   set the tooltip of me to the mousetext
end mouseMove
