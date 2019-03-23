Script "stack_Object_Selector_button_id_1018"

/*
# Name: button "Button_1" of card id 1002 of stack "Object Selector" of stack "revRefactor"
# ID: button id 1018 of card id 1002 of stack "Object Selector" of stack "revRefactor"
*/


on mouseUp
  -- this is the cancel button
  -- add your own code here
  answer "close this stack?" with "no" and "yes"
  if it is "yes" then
    close this stack
  end if
end mouseUp
