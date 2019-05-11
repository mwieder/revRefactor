Script "stack_revRefactor_card_id_1141"

/*
# Name: card "Undeclared" of stack "revRefactor"
# ID: card id 1141 of stack "revRefactor"
*/


on resizeStack
   local tRect
   constant kOrphanField = "fldUndeclared"
   constant kOKButton = "Button_1"
   
   lock screen
   put the rect of field kOrphanField into tRect
   put the left of this card + 20 into item 1 of tRect
   put the right of this card - 20 into item 3 of tRect
   put the bottom of this card - 50 into item 4 of tRect
   set the rect of field kOrphanField to tRect
   
   set the bottom of button kOKButton to the bottom of this card - 20
   set the right of button kOKButton to the right of field kOrphanField
   unlock screen
end resizeStack

