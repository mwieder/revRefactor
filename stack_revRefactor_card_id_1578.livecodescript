Script "stack_revRefactor_card_id_1578"

/*
# Name: card "RenamedVariables" of stack "revRefactor"
# ID: card id 1578 of stack "revRefactor"
*/


constant kOrphanField = "fldOrphanList"
constant kOKButton = "Button_1"
constant kUndeclaredButton = "btnUndeclared"
constant kDuplicatesButton = "btnGlobals"
constant kScripLocalsButton = "btnScriptLocals"
constant kParamsButton = "btnParams"
constant kConstantsButton = "btnConstants"

on resizeStack
   local tRect
   
   lock screen
   put the rect of field kOrphanField into tRect
   put the left of this card + 20 into item 1 of tRect
   put the right of this card - 20 into item 3 of tRect
   put the bottom of this card - 50 into item 4 of tRect
   set the rect of field kOrphanField to tRect
   
   set the bottom of button kOKButton to the bottom of this card - 20
   set the right of button kOKButton to the right of field kOrphanField
   set the bottom of button kUndeclaredButton to the bottom of this card - 20
   set the left of button kUndeclaredButton to the left of field kOrphanField
   
   set the bottom of button kParamsButton to the bottom of this card - 20
   set the left of button kParamsButton to the right of button kUndeclaredButton + 5
   set the bottom of button kConstantsButton to the bottom of this card - 20
   set the left of button kConstantsButton to the right of button kParamsButton
   set the bottom of button kDuplicatesButton to the bottom of this card - 20
   set the left of button kDuplicatesButton to the right of button kConstantsButton
   set the bottom of button kScripLocalsButton to the bottom of this card - 20
   set the left of button kScripLocalsButton to the right of button kDuplicatesButton
   
   unlock screen
end resizeStack

on ShowOrHide pShow, pWhich
   local tLineNumber
   
   lock screen
   put 1 into tLineNumber
   repeat for each line tLine in field "fldOrphanList"
      if pWhich is in tLine then
         set the hidden of line tLineNumber of field "fldOrphanList" to not pShow
      else
         --set the hidden of line tLineNumber of field "fldOrphanList" to false
      end if
      add 1 to tLineNumber
   end repeat
   unlock screen
end ShowOrHide

command ShowAllLines
   --   local tLineNumber
   
   --   put 1 into tLineNumber
   --   repeat for each line tLine in field "fldOrphanList"
   --      set the hidden of line tLineNumber of field "fldOrphanList" to false
   --      add 1 to tLineNumber
   --   end repeat
   set the hidden of line 1 to 1 of field "fldOrphanList" to false
end ShowAllLines

command HandleOptions
   lock screen
   ShowAllLines
   ShowOrHide the hilite of button kParamsButton, "parameter"
   ShowOrHide the hilite of button kDuplicatesButton, "global"
   ShowOrHide the hilite of button kScripLocalsButton, "local"
   --ShowOrHide the hilite of button kConstantsButton, "handler local variable"
   ShowOrHide the hilite of button kConstantsButton, "constant"
   ShowOrHide the hilite of button kUndeclaredButton, "undeclared variable"
   unlock screen
end HandleOptions

on closeStackRequest
   hide this stack
end closeStackRequest
