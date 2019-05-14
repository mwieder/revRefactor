Script "stack_revRefactor_card_id_1119"

/*
# Name: card "Orphans" of stack "revRefactor"
# ID: card id 1119 of stack "revRefactor"
*/


on resizeStack
   local tRect
   constant kOrphanField = "fldOrphanList"
   constant kOKButton = "Button_1"
   constant kUndeclaredButton = "btnUndeclared"
   constant kDuplicatesButton = "btnDupes"
   constant kOrphansButton = "btnOrphans"
   constant kParamsButton = "btnParams"
   constant kHandlersButton = "btnHandlers"
   
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
   set the bottom of button kHandlersButton to the bottom of this card - 20
   set the left of button kHandlersButton to the right of button kParamsButton
   set the bottom of button kDuplicatesButton to the bottom of this card - 20
   set the left of button kDuplicatesButton to the right of button kHandlersButton
   set the bottom of button kOrphansButton to the bottom of this card - 20
   set the left of button kOrphansButton to the right of button kDuplicatesButton
   
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
   local tLineNumber
   
   put 1 into tLineNumber
   repeat for each line tLine in field "fldOrphanList"
      set the hidden of line tLineNumber of field "fldOrphanList" to false
      add 1 to tLineNumber
   end repeat
end ShowAllLines

command HandleOptions
   lock screen
   ShowAllLines
   ShowOrHide the hilite of button "btnParams", "unused parameter"
   ShowOrHide the hilite of button "btnDupes", "duplicate"
   ShowOrHide the hilite of button "btnHandlers", "unused function"
   ShowOrHide the hilite of button "btnHandlers", "unused command"
   ShowOrHide the hilite of button "btnHandlers", "unused getprop"
   ShowOrHide the hilite of button "btnHandlers", "unused setprop"
   ShowOrHide the hilite of button "btnOrphans", "orphan"
   unlock screen
end HandleOptions
