Script "stack_revRefactor_card_id_1002"

/*
# Name: card "card id 1002" of stack "revRefactor"
# ID: card id 1002 of stack "revRefactor"
*/


/**
* openStack
* When this stack is in the user Plugins folder
* It is set to open when the IDE launches
* this inserts this script into the backscripts
*/
on preOpenStack
   local tPath
   
   insert the script of this stack into front
   dispatch "ideSubscribe" to me with "ideEditScript"
   
   -- installer (in case PowerTools isn't already in the user plugins folder)
   try
      if there is a stack "revmenubar" then
         put revEnvironmentUserPluginsPath() into tPath
      else
         -- MetaCard
         put specialfolderpath("documents") & "/Plugins" into tPath
         put "Plugins" into tPath
      end if
      if tPath is not empty then
         if there is a file (tPath & "/Refactor.livecode") then
         else
            answer "Do you want to install Refactor support into your user plugins folder?" with "Yes" and "No"
            if it is "Yes" then
               if there is no folder tPath then
                  create folder tPath
               end if
               set the filename of this stack to (tPath & "/Refactor.livecode")
               save this stack as (tPath & "/Refactor.livecode")
            end if
         end if
      end if
   catch e
   end try
   
end preOpenStack

on closeStack
   remove the script of this stack from back
   revIDEUnsubscribeAll
end closeStack

on ideEditScript
   --put "hello" & cr after msg
end ideEditScript
