Script "stack_revRefactor_card_id_1119"

/*
# Name: card "Orphans" of stack "revRefactor"
# ID: card id 1119 of stack "revRefactor"
*/


on resizeStack
   local tRect
   
   lock screen
   put the rect of field "fldOrphanList" into tRect
   put the left of this card + 20 into item 1 of tRect
   put the right of this card - 20 into item 3 of tRect
   put the bottom of this card - 50 into item 4 of tRect
   set the rect of field "fldOrphanList" to tRect
   
   set the bottom of button "Button_1" to the bottom of this card - 20
   set the right of button "Button_1" to the right of field "fldOrphanList"
   unlock screen
end resizeStack
