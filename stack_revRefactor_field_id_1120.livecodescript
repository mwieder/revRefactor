Script "stack_revRefactor_field_id_1120"

/*
# Name: field "fldOrphanList" of card "Orphans" of stack "revRefactor"
# ID: field id 1120 of card id 1119 of stack "revRefactor"
*/


on mouseUp
   local tLineNumber
   
   put word 1 of the selectedtext into tLineNumber
   dispatch "goLine" to group "Editor" of stack refactorSEName() with tLineNumber, true
end mouseUp
