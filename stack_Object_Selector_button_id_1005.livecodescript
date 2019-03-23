Script "stack_Object_Selector_button_id_1005"

/*
# Name: button "btnObjects" of group id 1004 of card id 1002 of stack "Object Selector" of stack "revRefactor"
# ID: button id 1005 of group id 1004 of card id 1002 of stack "Object Selector" of stack "revRefactor"
*/


on menuPick pChosen
   local tSelected
   
   set the itemdelimiter to "|"
   repeat with x = the number of items in pChosen to 1 step -1
      if tSelected is not empty then
         put " of " after tSelected
      end if
      put item x of pChosen after tSelected
   end repeat
   set the dialogdata to tSelected
   close this stack
end menuPick
