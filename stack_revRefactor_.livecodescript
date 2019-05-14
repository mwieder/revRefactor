Script "stack_revRefactor_"

/*
# Name: stack "revRefactor"
# ID: stack "revRefactor"
*/


Script "stack_revRefactor_"

/*
# Name: stack "revRefactor"
# ID: stack "revRefactor"
*/


/**
* LiveCode Refactoring support
*
* Mark Wieder
* Ah, Software
* https://www.ahsoftware.net
*
* licensing per the About box
*
* public handlers here:
* activateGLX2se
* activateIDEse
* refactorSEName
*
* revHookBuildScriptEditorMenu
* revHookScriptEditorMenuPick
* revHookBuildScriptEditorContextMenu
* revHookScriptEditorContextMenuPick
*
* declareLocalVariable
* 
*/

--> * history

/**
2012.05.29 mdw
* Added extra dimension to sUndoPointArray to support multiple tabs
* Localized any direct access to sUndoPointArray to UndoRetrive and Undo.Store
2012.05.31.mdw
* Moved low-level Undo code to mainstack
* Added extra type parameter "refactor" for multiple undo types
2012.08.02 mdw
* Fixed DoReplace if keyword is end of line, as in "exit grunt"
2019.01.04 mdw
* Extracted from glx2 for use in IDE's script editor
2019.01.27 mdw
* Added support for getters and setters
2019.03.08 mdw fixed getter/setter private declaration
* partially implemented cascading dispatch command
2019.03.20 mdw release 1.0.1
* added "Go Back" to Edit menu
2019.04.07 mdw version 1.0.4
* needed to use rugged ID rather than long id when talking to the SE
* need to use long id for the undo mechanism
* RenameHandler now only modifies external scripts if there is no handler of the same name in them.
* Still not ideal, but probably the best compromise for now.
* Same for ChangeSignature.
2019.04.25 mdw version 1.0.5
* AddDocsAtLine now allows for clicking anywhere in a handler to create documentation for that handler
* RenameVariable had misplaced lineCount incrementer : fixed per Bernd
2019.05.02 mdw version 1.0.6
* modified FindOrphans to catch orphan "put <xyz>" statements
* listUndeclaredVariablesIn had a misplaced chopIf statement -- bn
2019.05.03 mdw version 1.0.7
* move or copy without substacks was throwing an error
* explictVars is *not* set with strict compilation mode
* added tooltips to orphan code display since it isn't resizable
2019.05.07 mdw
* fixed the object selector for CopyOrMove in scriptObjectsOfObject
* added bn's patches to ensure no duplicate copies
2019.05.08 mdw
* listOrphansOfType needed tweaking after refactoring (irony rears its ugly head)
* don't remember why filteredScript was trying to filter out regex "\**"
2019.05.11 mdw version 1.0.9
* serious refactoring of availableHandlersOf because:
* it wasn't returning the right information if there were unapplied edits
* and it needed a multidimensional array to catch duplicate handlers
2019.05.11 mdw version 1.0.10
* reworked DoReplace to handle quoted strings
* and that required a one-line change to ChangeSignatureInScript
2019.05.12 mdw
* FindDuplicates now flags ALL occurences of duplicate handlers
* Constants are no longer flagged as unused (oops)...
* and this uncovered the fact that the scope of script-local variables was being reported incorrectly
* now catching getProp and setProp handlers as well as commands and functions
* and reporting them as such for unused and duplicate lists
*
* lots of tweaking to handle backslashes
* and ensure that script-local constants aren't flagged as unused
2019.05.13 mdw
* addedd a missing removeCommentsFrom() call to FindOrphans
* group duplicate handlers by type rather than sorting by line number
* added unused parameters to FindOrphans list
* also catching @parameters properly now
* improved speed of removing block comments (bn's function)
2019.05.14 mdw
* removed some unused local variables
* removed unused parameters from AddDocsAtLine, AddTestAtLine, ChangeSignature, scriptObjectsOfObject, CurrentObject
*/

/*
* Known issues:
* If the command name and variable are the same, the variable is flagged as being used.
* obviously it's not a good coding style, but still...
command hello
   local hello
end hello

* still a problem with multiline puts (the script editor also trips over this):
on mouseUp
   local tText
   put "what" & " no " &\/* any*/
         "more" into tText
end mouseUp

*/

-- some fake constants
local kCodeField = "Script"
local main = "revNewScriptEditor 1"

local sBreadCrumbs

constant kNotImplemented = "Not yet implemented. Coming Real Soon Now"
constant kThisScript = "This script only"
constant kKeywords = "end,private,on,command,function,getProp,setProp,before,after"
constant self = "revRefactor"

local sNewParamsArray
local sScriptArray
local sObjectHandlersArray

command activateGLX2se
   put "code storage" into kCodeField
   put "revGLX2 Code" into main
end activateGLX2se

command activateIDEse
   put "Script" into kCodeField
   put "revNewScriptEditor 1" into main
end activateIDEse

-- getter function to retrieve the name of the current script editor
function refactorSEName
   return main
end refactorSEName

--> IDE editor menu functions

-- https://quality.livecode.com/show_bug.cgi?id=21899
-- this mess could all be fixed if the script editor would check
--  if it is "unhandled"
-- instead of
--  if it is not "handled"
-- instead we have to recurse and unwind the stack frame on exit
on revHookBuildScriptEditorContextMenu pObjectID, pSelectedText, pText, @pModifiedText
   -- prevent recursion
   if param(0) is not in line -2 of the executionContexts then
      -- only do this the first time around
      put generateRefactoringSubmenu() after pText
      put  cr & "Go Back" & cr after line 1 of pText
      put pText into pModifiedText
      -- allow chaining dispatch messages without recursion
      dispatch "revHookBuildScriptEditorContextMenu" with pObjectID, pSelectedText, pText, pModifiedText
   else
      -- pass the command after the first iteration
      pass "revHookBuildScriptEditorContextMenu" with pObjectID, pSelectedText, pText, pModifiedText
   end if
   -- return "handled"  whether there's more or not
   return "handled" for value
end revHookBuildScriptEditorContextMenu

on revHookBuildScriptEditorMenu pMenuName, pMenu, @pModifiedMenu
   -- prevent recursion
   if param(0) is not in line -2 of the executionContexts then
      if pMenuName is "Edit" then
         put generateRefactoringSubmenu() after pMenu
      end if
      put pMenu into pModifiedMenu
      -- allow chaining dispatch messages without recursion
      dispatch "revHookBuildScriptEditorMenu" with pMenuName, pMenu, pModifiedMenu
   else
      pass "revHookBuildScriptEditorMenu" with pMenuName, pMenu, pModifiedMenu
   end if
   return "handled" for value
end revHookBuildScriptEditorMenu

constant kRefactors = "Rename Handler,Rename Variable,Convert Literal To Constant,Change Signature,Safe Delete,Move Handler To,Copy Handler To,Create Getter and Setter,Add Documentation,Add Test"

private function generateRefactoringSubmenu
   local tAddedText
   
   put "-" & cr & "Refactoring" & cr after tAddedText
   set the itemDelimiter to comma
   repeat for each item tRefactor in kRefactors
      put tab & tRefactor & cr after tAddedText
   end repeat
   put tab & "Convert Global to" & cr after tAddedText
   put tab & tab & "Script Local" & cr after tAddedText
   put tab & tab & "Getter and Setter" & cr after tAddedText
   put tab & tab & "Property" & cr after tAddedText
   put tab & "Convert Variable to" & cr after tAddedText
   put tab & tab & "Script Local" & cr after tAddedText
   put tab & tab & "Parameter" & cr after tAddedText
   put tab & tab & "Property" & cr after tAddedText
   put tab & "Extract to" & cr after tAddedText
   put tab & tab & "Command" & cr after tAddedText
   put tab & tab & "Function" & cr after tAddedText
   put tab & "Find Orphan Code" & cr after tAddedText
   put tab & "Undo Last Refactor" & cr after tAddedText
   return tAddedText
end generateRefactoringSubmenu

private command refactorMenuPick pWhich
   local tObject
   local tSelectedText
   local tSelectedChunk
   
   delete variable sObjectHandlersArray
   delete variable sScriptArray
   delete variable sNewParamsArray
   
   put the short name of this stack into main -- bn's patch for multiple editors
   set the itemDelimiter to "|"
   if item 1 of pWhich is "Refactoring" then
      lock screen
      try
         put the selectedChunk into tSelectedChunk
         if the selectedtext is empty then
            click at the selectedLoc
            put the clickText into tSelectedText
            if tSelectedChunk is not empty then
               select tSelectedChunk
            end if
         else
            put the selectedtext into tSelectedText
         end if
      catch e
      end try
      unlock screen
      
      try
         switch item 2 of pWhich
            case "Convert Literal To Constant"
               ConvertLiteralToConstant tSelectedText
               break
            case "Change Signature"
               ChangeSignature --tSelectedText
               break
            case "Convert Global to"
               ConvertGlobalTo tSelectedText, item 3 of pWhich
               break
            case "Convert Variable to"
               ConvertLocalVariableTo tSelectedText, item 3 of pWhich
               break
            case "Create Getter and Setter"
               CreateGetterAndSetterFor tSelectedText
               break
            case "Extract to"
               Extract tSelectedText, item 3 of pWhich
               break
            case "Safe Delete"
               SafeDelete tSelectedText
               break
            case "Move Handler To"
               MoveHandler tSelectedText
               break
            case "Copy Handler To"
               CopyHandler tSelectedText
               break
            case "Rename Handler"
               renameHandler tSelectedText
               break
            case "Rename Variable"
               renameVariable tSelectedText
               break
            case "Add Test"
               AddTestAtLine --the selectedline
               break
            case "Add Documentation"
               AddDocsAtLine --the selectedline
               break
            case "Find Orphan Code"
               FindOrphans
               break
            case "Undo Last Refactor"
               put CurrentObject() into tObject
               Undo.Pop tObject
               break
            default
               throw kNotImplemented
               break
         end switch
      catch e
         answer e
      end try
   else
      local tMatches, tLine, tSelectedHandler
      set the itemdelimiter to comma
      try
         if the selectedtext is empty then
            click at the selectedLoc
            put the clickText into tSelectedHandler
         else
            put the selectedtext into tSelectedHandler
         end if
      catch e
      end try
      switch item 1 of pWhich
         case "Go Back"
            local tIndex
            local tDestination
            put word 2 of the selectedline into tIndex
            put the long id of CurrentObject() into tObject
            if sBreadCrumbs[tIndex,tObject] is empty then
               put item 1 of sBreadCrumbs["lastBreadCrumb"] into tLine
               put item 2 of sBreadCrumbs["lastBreadCrumb"] into tDestination
            else
               put item 1 of sBreadCrumbs[tIndex,tObject] into tLine
               put item 2 of sBreadCrumbs[tIndex,tObject] into tDestination
            end if
            if tDestination is not empty then
               dispatch "revSEGoExecutionPoint" to stack main with tDestination, tLine, true, true
               -- is this a good idea?
               delete variable sBreadCrumbs[tIndex,tObject]
            else
            end if
            break
         case "Go to definition"
            -- hijack Go to definition so we can record where we're going and where we've been
            put word 2 of the selectedline into tLine
            put CurrentObject() into tObject
            dispatch function "seMatchingDefinitions" to stack main with tSelectedHandler, tObject
            if it is "handled" then
               put the result into tMatches
               if tMatches is not empty then
                  put tLine,tObject into sBreadCrumbs[item 4 to 5 of line 1 of tMatches]
                  put tLine,tObject into sBreadCrumbs["lastBreadCrumb"]
               end if
            end if
            break
         default
      end switch
   end if
end refactorMenuPick

on revHookScriptEditorMenuPick pMenuName, pWhich
   switch pMenuName
      case "Edit"
         refactorMenuPick pWhich
         break
   end switch
   pass revHookScriptEditorMenuPick
end revHookScriptEditorMenuPick

on revHookScriptEditorContextMenuPick pWhich
   refactorMenuPick pWhich
   pass revHookScriptEditorContextMenuPick
end revHookScriptEditorContextMenuPick

--> Refactor support

private function scriptFromEditor pObject
   local tReturnValue
   
   lock screen
   if pObject is not empty then
      edit the script of pObject
   end if
   dispatch function "textGetScript" to group "Editor" of stack main
   if it is "unhandled" then
      throw "unhandled function textGetScript"
   end if
   put the result into tReturnValue
   unlock screen
   return tReturnValue
end scriptFromEditor

private command CreateGetterAndSetterFor pVariableName
   local tScript
   
   put scriptFromEditor() into tScript
   insertGetterAndSetter pVariableName, tScript
   ConvertLocalVariableToScriptLocal pVariableName, tScript
   SetScript tScript
end CreateGetterAndSetterFor

/**
* ConvertLiteralToConstant
*/
private command ConvertLiteralToConstant pLiteral
   local tScript
   local tLineToInsert
   local tConstant
   local tInsertionPoint
   local tSuccess?
   local tObject
   
   put false into tSuccess?
   -- select the whole word
   if pLiteral is a number then
      click at the selectedLoc
      put the clickText into pLiteral
   end if
   put CurrentObject() into tObject
   put scriptFromEditor() into tScript
   
   -- find line for insertion
   put InsertionPoint(tScript) into tInsertionPoint
   
   -- create constant
   put pLiteral into tConstant
   replace quote with empty in tConstant
   put "k" before tConstant
   if "constant" && tConstant is not in tScript then
      put "constant" && tConstant && "= " into tLineToInsert
      if pLiteral is a number then
      else
         if char 1 of pLiteral is not quote then
            put quote & pLiteral & quote into pLiteral
         end if
      end if
      replace pLiteral with tConstant in tScript
      
      put pLiteral & cr after tLineToInsert
      -- insert tLineToInsert at insertion point
      if tInsertionPoint is not 0 then
         put tLineToInsert before line tInsertionPoint of tScript
         SetScript tScript, tObject
         put true into tSuccess?
      else
         Undo.Pop tObject, "Undo.RestoreScript"
      end if
   end if
   return tSuccess?
end ConvertLiteralToConstant

/**
* ConvertGlobalToLocal
*/
private command ConvertGlobalTo pVariableName, pType
   local tType
   local tScript, tGlobalScript
   local tObject
   
   if pType is empty then
      answer "Convert to" with "Script Local" and "Getter and Setter" and "Property" and "Cancel"
      put it into tType
   else
      put pType into tType
   end if
   
   put CurrentObject() into tObject
   put scriptFromEditor() into tScript
   -- see if the global was declared
   put filteredScript("global *" & pVariableName & "*", tScript) into tGlobalScript
   
   if tGlobalScript is not empty then
      -- remove global declarations
      do "global" && pVariableName & ";delete variable" && pVariableName
      if tType is not "Cancel" then
         set the itemdelimiter to comma
         switch tType
            case "this handler only"
               -- find start of handler + 1
               addLocalVariableToHandler pVariableName, tScript
               break
               
            case "Getter and Setter"
               insertGetterAndSetter pVariableName, tScript
            case "Script Local"
               repeat for each line tLine in tGlobalScript
                  RemoveDeclaration pVariableName, "global", tLine, 0, tScript
               end repeat
               -- find line for insertion
               insertAtStartOfScript "local" && pVariableName, tScript
               break
            case "Property"
               ConvertLocalVariableTo pVariableName, "property"
               exit ConvertGlobalTo
               break
         end switch -- scope of global
         SetScript tScript, tObject
      end if
   end if
end ConvertGlobalTo

private command addLocalVariableToHandler pVariableName, @pScript
   local tInsertionPoint
   local tStartLineNumber, tEndLineNumber
   local tGlobalScript
   
   put ContextForCurrentLine() into tInsertionPoint
   put word 3 of tInsertionPoint into tStartLineNumber
   put word 4 of tInsertionPoint into tEndLineNumber
   put line tStartLineNumber+1 to tEndLineNumber of pScript into tGlobalScript
   
   repeat for each line tLine in tGlobalScript
      RemoveDeclaration pVariableName, "global", tLine, 0, pScript
   end repeat
   put cr & tab & "local" && pVariableName after line tStartLineNumber of pScript
end addLocalVariableToHandler

/**
* Public because it's invoked from field "fldUndeclared" of card "Undeclared"
*/
command declareLocalVariable pVariableName
   local tScript
   
   put scriptFromEditor() into tScript
   addLocalVariableToHandler pVariableName, tScript
   SetScript tScript, CurrentObject()
end declareLocalVariable

private command RemoveDeclaration pVariableName, pType, pLine, pOffset, @pScript
   local tLinePos
   local tLine, tReplacedLine
   constant kTypes = "global,local"
   
   -- TODO: See if it's safe to delete the declaration
   -- by seeing if it's used anywhere else
   -- this includes globals and script locals
   put lineoffset(pLine, pScript, pOffset) into tLinePos
   put line tLinePos of pScript into tLine
   set the itemdelimiter to comma
   
   if word 1 of tLine is among the items of kTypes then
      replace pVariableName with space in tLine
      if the number of words in tLine is 1 then
         put empty into line tLinePos of pScript
         delete line tLinePos of pScript
      else
         put line tLinePos of pScript into tLine
         put replacetext(tLine, "(?i)[, ]*"& regexWholeWordFrom(pVariableName), "") into tReplacedLine
         chopIf comma, tReplacedLine
         replace "global," with "global " in tReplacedLine
         replace "local," with "local " in tReplacedLine
         if word 1 to -1 of tReplacedLine is not empty then
            put tReplacedLine into line tLinePos of pScript
         end if
      end if
   end if
   return pScript
end RemoveDeclaration

private function regexWholeWordFrom pWord
   return "\b" & pWord & "\b"
end regexWholeWordFrom

/**
* ConvertLocalVariableTo
* convert local variable to
*  script-local variable
*  parameter of the containing handler
*  property
*/
private command ConvertLocalVariableTo pVariableName, pType
   local tType
   local tScript
   local tLocalScript, tLocalScriptArray
   local tInsertionPoint
   local tStartLineNumber, tEndLineNumber
   local tObject
   local tLineCount
   
   if pType is empty then
      answer "Convert to" with "script local" and "parameter" and "property" and "Cancel"
      put it into tType
   else
      put pType into tType
   end if
   if tType is not "Cancel" then
      put CurrentObject() into tObject
      put scriptFromEditor() into tScript
      set the itemdelimiter to comma
      switch tType
         case "script local"
            -- see if the variable was declared
            put filteredScript("local *" & pVariableName & "*", tScript) into tLocalScriptArray
            put tLocalScriptArray into tLocalScript
            -- no local declaration
            if tLocalScript is empty then
               if filteredScript("global *" & pVariableName & "*", tScript) is empty then
                  Undo.Pop tObject, "Undo.RestoreScript"
                  insertAtStartOfScript "local" && pVariableName, tScript
               else
                  -- convert the local global to a script local
                  ConvertLocalVariableToScriptLocal pVariableName, tScript
               end if
            else
               -- already declared, so there's more work to do
               ConvertLocalVariableToScriptLocal pVariableName, tScript
            end if
            break
         case "parameter"
            local tWordCount
            
            -- find start of handler
            put ContextForCurrentLine() into tInsertionPoint
            put word 3 of tInsertionPoint into tStartLineNumber
            put word 4 of tInsertionPoint into tEndLineNumber
            put line tStartLineNumber+1 to tEndLineNumber of tScript into tLocalScript
            
            -- ensure the parameter does not already exist
            put 2 into tWordCount
            if pVariableName is not among the words of line tStartLineNumber of tScript then
               if word 1 of line tStartLineNumber of tScript is "private" then
                  add 1 to tWordCount
               end if
               -- see if there are already any parameters
               if the number of words in line tStartLineNumber of tScript > tWordCount then
                  put comma after line tStartLineNumber of tScript
               end if
               put space & pVariableName after line tStartLineNumber of tScript
            end if
            if variableIsInHandler?(pVariableName, tLocalScript) is false then
               -- must be script-local, so grab the whole script
               put tScript into tLocalScript
               put 0 into tStartLineNumber
               put -1 into tEndLineNumber
            end if
            put 1 into tLineCount
            repeat for each line tLine in tLocalScript
               switch word 1 of tLine
                  case "global"
                  case "local"
                     RemoveDeclaration pVariableName, word 1 of tLine, tLine, 0, tLocalScript
                     insertText tLocalScript, tStartLineNumber, tEndLineNUmber, tScript
               end switch
               add 1 to tLineCount
            end repeat
            break
         case "property"
            local tTargetObject
            ask "property of what object?"
            if it is not empty then
               put it into tTargetObject
               set the wholematches to true
               local tLines
               put the number of lines in tScript into tLines
               -- find start of handler
               put ContextForCurrentLine() into tInsertionPoint
               put word 3 of tInsertionPoint into tStartLineNumber
               put word 4 of tInsertionPoint into tEndLineNumber
               put line tStartLineNumber+1 to tEndLineNumber of tScript into tLocalScript
               -- see if we're dealing with a script-local or handler-local variable
               -- see if it's in the current handler
               if variableIsInHandler?(pVariableName, tLocalScript) is false then
                  -- must be script-local, so grab the whole script
                  put tScript into tLocalScript
                  put 0 into tStartLineNumber
                  put -1 into tEndLineNumber
               end if
               put 1 into tLineCount
               repeat for each line tLine in tLocalScript
                  switch word 1 of tLine
                     case "end"
                        if char 1 to 3 of tLine is "end" then
                           -- at end of current handler
                           if tStartLineNumber is not zero then
                              exit repeat
                           end if
                        end if
                        break
                     case "global"
                     case "local"
                        if pVariableName is in tLine then
                           RemoveDeclaration pVariableName, word 1 of tLine, tLine, 0, tLocalScript
                           insertText tLocalScript, tStartLineNumber, tEndLineNUmber, tScript
                           -- see if we deleted a line; adjust the line count if so
                           if the number of lines in tScript < tLines then
                              put the number of lines in tScript into tLines
                              subtract 1 from tLineCount
                           end if
                        end if
                        break
                     default
                        if pVariableName is in tLine then
                           ConvertVariableToProperty pVariableName, tTargetObject, tLine
                           put tLine into line tLineCount+tStartLineNumber of tScript
                        end if
                        break
                  end switch
                  add 1 to tLineCount
               end repeat
               
            else
               throw kNotImplemented
               exit ConvertLocalVariableTo
            end if
         default
      end switch -- tType
      SetScript tScript, tObject
   end if -- tType is "Cancel"
end ConvertLocalVariableTo

private command insertText pText, pStartLineNumber, pEndLineNUmber, @pScript
   put pText into line pStartLineNumber+1 to pEndLineNumber of pScript
end insertText

private command insertGetterAndSetter pVar, @pScript
   local kCRLF, kTAB
   
   constant kGetter = "function [[pVar]][[kCRLF]][[kTAB]]return [[pVar]][[kCRLF]]end [[pVar]][[kCRLF]]"
   constant kSetter = "command set[[pVar]]To pValue [[kCRLF]][[kTAB]]put pValue into [[pVar]][[kCRLF]]end set[[pVar]]To[[kCRLF]]"
   
   -- set up the fake constants bc we can't have that kind of constant in LC
   put crlf into kCRLF
   put tab into kTAB
   insertAtStartOfScript merge(kSetter), pScript
   insertAtStartOfScript merge(kGetter), pScript
end insertGetterAndSetter

private function variableIsInHandler? pVariableName, pScript
   -- see if it's in the current handler
   filter pScript with "*local *" & pVariableName & "*"
   return pScript is not empty
end variableIsInHandler?

private function globalIsInHandler? pVariableName, pScript
   -- see if it's in the current handler
   filter pScript with "*global *" & pVariableName & "*"
   return pScript is not empty
end globalIsInHandler?

/**
* ConvertLocalVariableToScriptLocal
* command
*  @pVariableName
*  @@pScript
*
* At this point we know the variable is already declared somewhere
*/
private command ConvertLocalVariableToScriptLocal pVariableName, @pScript
   local tInsertionPoint
   local tStartLineNumber, tEndLineNumber
   local tLocalScript
   
   put ContextForCurrentLine() into tInsertionPoint
   put word 3 of tInsertionPoint into tStartLineNumber
   put word 4 of tInsertionPoint into tEndLineNumber
   put line tStartLineNumber+1 to tEndLineNumber of pScript into tLocalScript
   
   if variableIsInHandler?(pVariableName, tLocalScript) is false \
         and globalIsInHandler?(pVariableName, tLocalScript) is false then
      -- must be script-local, so grab the whole script
      put pScript into tLocalScript
      put 0 into tStartLineNumber
      put -1 into tEndLineNumber
   else
      insertAtStartOfScript "local" && pVariableName, pScript
      add 1 to tStartLineNumber
      add 1 to tEndLineNumber
      repeat for each line tLine in tLocalScript
         switch word 1 of tLine
            case "global"
            case "local"
               if pVariableName is in tLine then
                  RemoveDeclaration pVariableName, word 1 of tLine, tLine, 0, tLocalScript
                  insertText tLocalScript, tStartLineNumber, tEndLineNUmber, pScript
               end if
         end switch
      end repeat
   end if
end ConvertLocalVariableToScriptLocal

private command ConvertVariableToProperty pVariableName, pObject, @pScriptLine
   constant kSet = "set the [[pVariableName]] of [[pObject]] to"
   
   if "put" is word 1 of pScriptLine and pVariablename is word -1 of pScriptLine then
      put merge(kSet) into word 1 of pScriptLine
      delete word -2 to -1 of pScriptLine
   else
      put replacetext(pScriptLine, "(?i)"& regexWholeWordFrom(pVariableName), "the" && pVariableName && "of" && pObject) into pScriptLine
   end if
   return pScriptLine
end ConvertVariableToProperty

/**
* ChangeSignature
* change the order and/or number of parameters
*/
private command ChangeSignature --pContextText
   local tList
   local tScript
   local tInsertionPoint
   local tStartLineNumber
   local tEndLineNumber
   local tLine
   local tHandlerName, tNewHandlerName
   local tParamsArray
   local tNewSignature
   local tType
   local x
   
   -- see if it's a command or function
   put HandlerType() into tType
   put scriptFromEditor() into tScript
   set the itemDelimiter to comma
   set the wholematches to true
   put ContextForCurrentLine() into tInsertionPoint
   put word 3 of tInsertionPoint into tStartLineNumber
   put word 4 of tInsertionPoint into tEndLineNumber
   
   put line tStartLineNumber of tScript into tLine
   put 0 into x
   repeat while char -1 of tLine is "\"
      add 1 to x
      put line tStartLineNumber+x of tScript into char -1 of tLine
   end repeat
   if x is not 0 then
      put " to " & tStartLineNumber+x after tStartLineNumber
   end if
   if word 1 of tLine is "private" then
      delete word 1 of tLine
   end if
   put word 2 of tLine into tHandlerName
   
   -- put the parameter locations in an array
   -- whose keys are the parameters
   put OriginalParams(tLine) into tParamsArray
   
   ask "Edit Signature" with line tStartLineNumber of tScript
   if it is not empty and it is not line tStartLineNumber of tScript then
      put it into tNewSignature
      -- if it's a private handler there's no need to check other scripts
      if word 1 of tLine is not "private" then
         put WhereUsed(tHandlerName, tType) into tList
      end if
      -- adjust this script to start with
      ChangeSignatureInEditorScript tStartLineNumber, tEndLineNumber, tHandlerName, tNewSignature, tParamsArray, tScript
      SetScript tScript
      if tList is empty then
         -- this script only
      else
         -- WhereUsed() returned list of other scripts where used
         repeat for each line tObject in tList
            put the script of tObject into tScript
            if word 1 of tNewSignature is "private" then
               put word 3 of tNewSignature into tNewHandlerName
            else
               put word 2 of tNewSignature into tNewHandlerName
            end if
            if ShouldSkipScript?(tScript) then
            else
               ChangeSignatureInScript tHandlerName, tNewHandlerName, sNewParamsArray, tScript
               SetScript tScript, tObject
            end if
         end repeat
      end if
   else
      -- user wants to cancel, not change signature
   end if
end ChangeSignature

private function OriginalParams pLine
   local tOldParams
   local tParamsArray
   local x
   
   -- put the parameter locations in an array
   -- whose keys are the parameters
   set the itemdelimiter to comma
   put word 3 to -1 of pLine into tOldParams
   put token 1 to -1 of tOldParams into tOldParams
   repeat with x=1 to the number of items in tOldParams
      put x into tParamsArray[word 1 of item x of tOldParams]
   end repeat
   return tParamsArray
end OriginalParams

/**
* ChangeSignatureInEditorScript
*
* Change the command or function declaration,
* then call ChangeSignatureInScript to change calls to the handler
*/
private command ChangeSignatureInEditorScript pStartLineNumber, pEndLineNumber, pHandlerName, pNewSignature, pParamsArray, @pScript
   local tNewHandlerName
   local tParamOffset
   local tIsPrivate
   local tParameters
   local tOldPosition
   local tObject
   local x
   
   set the itemDelimiter to comma
   set the wholematches to true
   put false into tIsPrivate
   put CurrentObject() into tObject
   delete variable sNewParamsArray
   
   -- replace the handler declaration itself
   put pNewSignature into line pStartLineNumber of pScript
   put 3 into tParamOffset
   if word 1 of pNewSignature is "private" then
      put true into tIsPrivate
      delete word 1 of pNewSignature
   end if
   put word 2 of pNewSignature into tNewHandlerName
   -- change the end of the declaration
   replace pHandlerName with tNewHandlerName in line pEndLineNumber of pScript
   
   -- gather the parameter positions list
   put 1 into x
   put word tParamOffset to -1 of pNewSignature into tParameters
   repeat for each item tParameter in tParameters
      -- see if the parameter is in the old list
      put pParamsArray[word 1 of tParameter] into tOldPosition
      if tOldPosition is not empty then
         -- tNewParamsArray is a transposition array
         -- whose keys are the new position
         -- and values are the old position
         put tOldPosition into sNewParamsArray[x]
      else
         put numtochar(3) & word 1 of tParameter into sNewParamsArray[x]
      end if
      add 1 to x
   end repeat
   
   -- now change all calls to this handler
   ChangeSignatureInScript pHandlerName, tNewHandlerName, sNewParamsArray, pScript
end ChangeSignatureInEditorScript

/**
* ChangeSignatureInScript
*
* Change calls to the handler
*/
private command ChangeSignatureInScript pHandlerName, pNewHandlerName, pNewParamsArray, @pScript
   local tReplacement
   local tTestParameters
   local tTestScript
   local tOffset
   local tLineNumber, tLineNumbers
   local tFuncParams -- true if ther is a function call on the current line
   local tNewNumParameters
   local tOldNumParameters
   local tParams
   local tEndOfOldParameters -- note: this will be 0 if there are no original parameters
   
   set the itemDelimiter to comma
   set the wholematches to true
   -- replace parameters with actuals
   put 1 into tLineNumber
   put empty into tParams
   put pScript into tTestScript
   repeat for each line tTestLine in tTestScript
      put false into tFuncParams -- not a function until we say so
      
      -- allow for line continuations
      local tLineNumberEnd
      put tLineNumber into tLineNumbers
      put tLineNumber into tLineNumberEnd
      repeat while "\" is char -1 of tTestLine
         add 1 to tLineNumberEnd
         put word 1 to -1 of line tLineNumberEnd of tTestScript into char -1 of tTestLine
      end repeat
      if tLineNumberEnd is not tLineNumber then
         put " to" && tLineNumberEnd after tLineNumbers
      end if
      
      -- see if the word we're replacing is in this line
      -- this fails to match doSomething with "doSomething"
      --put wordoffset(pHandlerName, tTestLine) into tOffset
      -- so we have to do this instead
      put offset(pHandlerName, tTestLine) into tOffset
      
      -- if the handler we're replacing is in this line then
      if tOffset > 0 then
         -- see if there is a function call on this line
         local tParenOffset
         put offset("(", tTestLine) into tParenOffset
         if tParenOffset > 0 then
            -- get the function parameters in the current line
            put matchtext(tTestLine, "\((.*)\)", tTestParameters) into tFuncParams
            put length(tTestParameters) into tEndOfOldParameters
         else
            -- command, not function
            put offset(char -1 of token -1 of tTestLine, tTestLine)+1 into tEndOfOldParameters
         end if
         
         local tShouldHandleThis
         local tCharPos
         put false into tShouldHandleThis
         switch word 1 of tTestLine
            case "send"
               put wordoffset ("to", tTestLine) into tCharPos
               put word 2 to tCharPos-1 of tTestLine into tParams
               replace quote with empty in tParams
               put token 2 to -1 of tParams into tTestParameters
               put true into tShouldHandleThis
               break
            case "dispatch"
               put wordoffset ("with", tTestLine) into tCharPos
               put word tCharPos+1 to -1 of tTestLine into tParams
               put tParams into tTestParameters
               put true into tShouldHandleThis
               break
            case pHandlerName -- handler is first word in line
               if tParenOffset is 0 or tOffset < tParenOffset then
                  put true into tShouldHandleThis
                  put word 2 to -1 of tTestLine into tParams
                  put tParams into tTestParameters
               end if
               break
            default
               if tOffset < tParenOffset then
               else
                  break
               end if
            case "call"
               put true into tShouldHandleThis
               break
         end switch
         
         if tShouldHandleThis then
            if word 1 of tTestLine is not in kKeywords then
               -- get the parameters of the line we're substituting into
               -- is this a function call?
               if tParenOffset > 0 then
               else
                  -- not a function call, get the command parameters
               end if
               
               put the number of items in tTestParameters into tOldNumParameters
               
               -- replace the handler name
               put DoReplace(tTestLine, pHandlerName, pNewHandlerName) into tTestLine
               put tTestLine into line tLineNumber of pScript
               
               -- enable this test to leave func() (no parameters) intact
               --if tEndOfOldParameters > 0 then
               if word 1 of tTestLine is not in "exit" then
                  
                  -- replace the parameters
                  -- use whichever of tOldNumParameters or tNewNumParameters is bigger
                  put the number of elements in pNewParamsArray into tNewNumParameters
                  if tNewNumParameters < tOldNumParameters then
                     put tOldNumParameters into tNewNumParameters
                  end if
                  
                  repeat with tOriginalindex=1 to tNewNumParameters
                     -- see if the parameter is in both old and new lists
                     -- tOriginalindex is the item index into the original parameters,
                     -- tNewParamsArray[tOriginalindex] will have the new location
                     if pNewParamsArray[tOriginalindex] is a number then
                        -- it is, so index into the parameters of the current line
                        -- grab that parameter, and use it
                        put item pNewParamsArray[tOriginalindex] of tTestParameters into tReplacement
                     else
                        -- delete the numtochar(3) from the beginning
                        put pNewParamsArray[tOriginalindex] into tReplacement
                        if char 1 of tReplacement is numtochar(3) then
                           delete char 1 of tReplacement
                        end if
                     end if
                     
                     put tReplacement into item tOriginalIndex of tParams
                  end repeat -- with tOriginalindex=1 to tNewNumParameters
                  chopIf comma, tParams
                  if char 1 of tParams is comma then
                     put "pUndelcaredParameter" before tParams
                  end if
                  
                  local tReplacementPosition, tEndpoint
                  put length(pNewHandlerName) + tOffset into tReplacementPosition
                  -- differentiate between a function and a command
                  if tFuncParams then
                     put tReplacementPosition+tEndOfOldParameters into tEndpoint
                     add 1 to tReplacementPosition
                     put tParams into char tReplacementPosition to tEndpoint of line tLineNumber of pScript
                  else
                     -- cover the case where there's just a command with no orig parameters
                     if tOldNumParameters < 1 then
                        put space before tParams
                     end if
                     add 1 to tReplacementPosition
                     put tReplacementPosition+tEndOfOldParameters into tEndpoint
                     
                     local tTokens
                     switch word 1 of tTestLine
                        case "call"
                           put token 2 to -1 of tTestLine into tTokens
                           if word 1 of tTokens is "function" then
                              delete word 1 of tTokens
                           end if
                           put word 2 of tTokens into tTokens
                           -- don't change call parameters
                           break
                        case "dispatch"
                           put tTestParameters into tTokens
                           break
                        default
                           put tTestParameters into tTokens
                     end switch
                     put DoReplace(tTestLine, tTokens, tParams) into line tLineNumber of pScript
                  end if -- tFuncParams
                  
               end if --  word 1 of tTestLine is not in "exit"
               --end if -- tEndOfOldParameters > 0
            end if
         else -- tOffset > tParenOffset
         end if -- word 1 of tTestLine is not in kKeywords
      end if -- (tOffset < tParenOffset) or (tParenOffset is 0)
      add 1 to tLineNumber
   end repeat
end ChangeSignatureInScript

/**
* Extract
*
* extract the given block of text to a new command or function
*/
private command Extract pText, pType
   local tHandler
   local tScript
   
   if pType is empty then
      answer "Create command or function?" with "Command" and "Function" and "Cancel"
      put it into pType
   end if
   if pType is not "Cancel" then
      ask "Name the handler"
      if it is not empty then
         put it into tHandler
         put scriptFromEditor() into tScript
         -- replace the calls to the new handler
         if pType is "Function" then
            put DoReplace(tScript, pText, tHandler & "()" & cr ) into tScript
         else
            put DoReplace(tScript, pText, tHandler & cr ) into tScript
         end if
         
         -- now put the handler at the end of the script
         put cr & pType && tHandler & cr \
               & pText & cr after tScript
         if pType is "Function" then
            put "return tReturn" & cr after tScript
         end if
         put "end" && tHandler & cr after tScript
         SetScript tScript
      end if
   end if
end Extract

constant kLineStarters = "private,on,command,function,after,before,getProp,setProp"

/**
*  AddTestAtLine
*
* Add a test for the given handler
* in a file in the same directory as the stack being edited
*/
private command AddTestAtLine --pSelectedLine
   local tScript, tFilteredScript
   local tLineNumber, tObjectNumber
   local tFunctionLine
   local tFunctionType, tFunction
   local tParameters
   local tGeneratedTest
   local tPathName, tFileName, tStackName
   local tOffset
   local tTestContents, tFileContents
   local tNextTestNumber, tNextObjectNumber
   
   put CurrentObject() into tPathName
   put the long id of tPathName into tPathName
   -- get just the stack name
   put "stack" && word -1 of tPathName into tFileName
   if the filename of tFileName is empty then
      answer "you need to save the stack first"
      return -1
   end if
   lock screen
   
   local tHandlerList
   put ContextForCurrentLine() into tHandlerList
   put word 3 of tHandlerList into tLineNumber
   put line tLineNumber of tScript into tFunctionLine
   
   if word 1 of tFunctionLine is in kLineStarters then
      if word 1 of tFunctionLine is "private" then
         delete word 1 of tFunctionLine
      end if
      put word 1 of tFunctionLine into tFunctionType
      put word 2 of tFunctionLine into tFunction
      delete word 1 to 2 of tFunctionLine
      if tFunctionLine is not empty then
         put tFunctionLine into tParameters
      end if
      
      if tLineNumber is empty then
         put filteredScript(tFunctionType && tFunction && "*", tScript) into tFilteredScript
         put lineoffset(tFilteredScript, tScript) into tLineNumber
      end if
      
      # get the path url to the stack being edited
      -- get just the stack name
      put word -1 of tPathName into tFileName
      set the itemdelimiter to "/"
      put item -1 of tFileName into tStackName
      put tStackName & ".tests" into item -1 of tFileName
      replace quote with empty in tFileName
      
      put GenerateTestFor(tFunctionType, tFunction, tParameters) into tGeneratedTest
      -- open or create the test file
      if there is a file tFileName then
         put url("file:" & tFileName) into tFileContents
         
         # adjust the handler names to avoid duplicates
         put NextTestNumber(tFunction, tFileContents) into tNextTestNumber
         replace "test" & tFunction with "test" & tFunction & tNextTestNumber in tGeneratedTest
         
         # do we need to add a new object reference?
         if (line 4 of tGeneratedTest) is not in tFileContents then
            put lineoffset("#end of objects", tFileContents) into tOffset
            put NextObjectNumber(tFileContents) into tNextObjectNumber
            replace "$NUMBER" with tNextObjectNumber in tGeneratedTest
            if line 4 of tGeneratedTest is not among the lines of tFileContents then
               put line 1 of tGeneratedTest & cr before line tOffset of tFileContents
               
               put lineoffset("command TestSuite.setup", tFileContents) into tOffset
               put cr & line 4 of tGeneratedTest after line tOffset of tFileContents
               delete line 1 to 6 of tGeneratedTest -- extra TestSuite.setup command
            end if
            
            put tFileContents into url ("file:" & tFileName)
         else
            # the reference already exists
            put filteredScript("#object*" & word 2 to -1 of line 1 of tGeneratedTest, tFileContents) into tTestContents
            
            put lineoffset(tTestContents, tFileContents) into tOffset
            put char 2 to -2 of word 1 of line tOffset of tFileContents into tObjectNumber
            delete line 1 to 6 of tGeneratedTest
            replace "object$NUMBER" with tObjectNumber in tGeneratedTest
         end if # do we need to add a new object reference?
      else
         # starting a new test file
         put CreateNewTestsFile(tFileName, tGeneratedTest) into tGeneratedTest
      end if # there is a file tFileName
      
      open file tFileName for append
      if the result is not empty then
         put "file open error:" && the result & cr after msg
      else
         -- append tGeneratedTest to the end of the test file
         write tGeneratedTest to file tFileName
         if the result is not empty then
            put "file write error:" && the result & cr after msg
         else
         end if
         close file tFileName
      end if
   end if # word 1 of tFunctionLine is in kLineStarters
   unlock screen
   return 0
end AddTestAtLine

private function NextObjectNumber pFileContents
   local tLastObjectNumber
   
   filter pFileContents with "local kObject*"
   if pFileContents is not empty then
      sort pFileContents
      put char 8 to -1 of word 2 of line -1 of pFileContents into tLastObjectNumber
      add 1 to tLastObjectNumber
   end if
   return tLastObjectNumber
end NextObjectNumber

/**
* NextTestNumber
* function
*  pLine :
*  @pScript :
* returns
*  tLastHandler
*/
private function NextTestNumber pFunction, pFileContents
   local tFindDupes
   local tLastHandler
   
   put filteredScript("test" & pFunction & "*", pFileContents) into tFindDupes
   if tFindDupes is not empty then
      sort tFindDupes
      put word 1 of line -1 of tFindDupes into tLastHandler
      replace "test" & pFunction with empty in tLastHandler
      add 1 to tLastHandler
   end if
   return tLastHandler
end NextTestNumber

private function CreateNewTestsFile pFilePath, pGeneratedTest
   local tFileHeader
   
   put "#script " & quote & pFilePath & quote & cr into tFileHeader
   put "#start of objects" & cr after tFileHeader
   replace "$NUMBER" with 1 in pGeneratedTest
   put line 1 of pGeneratedTest & cr after tFileHeader
   delete line 1 of pGeneratedTest
   put "#end of objects" & cr after tFileHeader
   put "#run with testRunner stack" & cr after tFileHeader
   put tFileHeader into url("file:" & pFilePath)
   return pGeneratedTest
end CreateNewTestsFile

/**
*  GenerateTestFor
*/
private function GenerateTestFor pType, pHandler, pParameters
   local tTestScript
   local tObject
   local tStackName
   if pType is "function" then
      put the uFunctionTestTemplate of me into tTestScript
   else
      put the uCommandTestTemplate of me into tTestScript
   end if
   replace "$HANDLER" with pHandler in tTestScript
   replace "$PARAMETERS" with pParameters in tTestScript
   put CurrentObject() into tObject
   put word -1 of tObject into tStackName
   put q(word 1 to -2 of tObject) && "&& q(" & tStackName & ")" into tObject
   replace "$OBJECT" with tObject in tTestScript
   put cr & "----" & cr after tTestScript
   return tTestScript
end GenerateTestFor

private function q pText
   return quote & pText & quote
end q

private command chomp @pText
   chopIf cr, pText
end chomp

private command chopIf pChar, @pText
   if char -1 of pText is pChar then
      chop pText
   end if
end chopIf

private command chop @pText
   delete char -1 of pText
end chop

/**
*  AddDocsAtLine
*/
private command AddDocsAtLine --pSelectedLine
   local tScript, tGeneratedTest
   local tLineNumber
   local tFunctionLine
   local tFunctionType, tHandlerName
   local tParameters
   local tHandlerList
   
   lock screen
   put scriptFromEditor() into tScript
   put ContextForCurrentLine() into tHandlerList
   put word 3 of tHandlerList into tLineNumber
   put line tLineNumber of tScript into tFunctionLine
   
   switch word 1 of tHandlerList
      case "PF"
         delete word 1 of tFunctionLine
      case "G"
      case "F"
         put "function" into tFunctionType
         break
      case "PM"
         delete word 1 of tFunctionLine
      case "S"
      case "M"
         put "command" into tFunctionType
         break
   end switch
   put word 2 of tHandlerList into tHandlerName
   if tFunctionLine is not empty then
      put token 3 to -1 of tFunctionLine into tParameters
   end if
   
   put word 3 of tHandlerList into tLineNumber
   put GenerateDocsFor(tLineNumber, tFunctionType, tHandlerName, tParameters) into tGeneratedTest
   put tGeneratedTest before line tLineNumber of tScript
   SetScript tScript
   unlock screen
end AddDocsAtLine

/**
*  GenerateDocsFor
*/
private function GenerateDocsFor pLine, pType, pHandler, pParameters
   local tScript, tFilteredScript
   local tTestScript
   local tParams
   
   put scriptFromEditor() into tScript
   if pLine is empty then
      put filteredScript(pType && pHandler && "*", tScript) into tFilteredScript
      put lineoffset(tFilteredScript, tScript) into pLine
   end if
   
   put docTemplateFor(pType) into tTestScript
   if pParameters is not empty then
      repeat for each item tParam in pParameters
         put "*  " & word 1 of tParam  && ":" & cr after tParams
      end repeat
      --delete char -1 of tParams
      chomp tParams
   else
      put "*" into tParams
   end if
   
   local tLine, tWordOffset, tToken
   local tReturnLine, tUpperLimit
   local tFunctionReturnValue
   local tHandlerList
   if pType is "function" then
      put ContextForCurrentLine() into tHandlerList
      put word 4 of tHandlerList into tUpperLimit
      repeat
         put lineoffset("return", tScript, pLine) into tReturnLine
         if tReturnLine <= 0 then
            exit repeat
         end if
         if tReturnLine+pLine > tUpperLimit then
            exit repeat
         end if
         put line (tReturnLine+pLine) of tScript into tLine
         put tokenoffset("return", tLine) into tWordOffset
         if tWordOffset is 1 then
            if tFunctionReturnValue is not empty then
               put cr & "*  " after tFunctionReturnValue
            end if
            put token tWordOffset+1 to -1 of tLine into tToken
            if tToken is empty then
               put "empty" into tToken
            end if
            put tToken after tFunctionReturnValue
         end if
         add tReturnLine to pLine
      end repeat
   end if
   return merge(tTestScript)
end GenerateDocsFor

-- could change the documentation templates here
-- by modifying the custom properties
private function docTemplateFor pType
   local tTestScript
   
   if pType is "function" then
      put the uFunctionDocsTemplate of me into tTestScript
   else
      put the uCommandDocsTemplate of me into tTestScript
   end if
   return tTestScript
end docTemplateFor

/**
* RenameVariable
*/
private command RenameHandler pVarName
   local tList
   local tRenameType
   local tNewName
   local tScript, tTestForLocal
   local tType
   local tEmptyArray
   local tObject
   
   if pVarName is not empty then
      -- see if it's a command or function
      put HandlerType() into tType
      -- first see if we're renaming a private handler.
      -- if so then we don't need to look at other scripts
      put CurrentObject() into tObject
      put scriptFromEditor() into tScript
      put filteredScript("private*" & pVarName & "*", tScript) into tTestForLocal
      if tTestForLocal is not empty then
         put kThisScript into tRenameType
      else
         answer "Rename globally?" with "All scripts in this stack" and kThisScript and "Cancel"
         put it into tRenameType
      end if
      
      if it is not "Cancel" then
         set the wholematches to true
         ask "New name for" && pVarName with pVarName
         put word 1 of it into tNewName
         if tNewName is empty or tNewName is pVarName then
            exit RenameHandler
         end if
         lock screen         
         local tInsertionPoint, tStartLineNumber, tEndLineNumber
         local tLine, tParamsArray, tOldParams
         put ContextForCurrentLine() into tInsertionPoint
         put word 3 of tInsertionPoint into tStartLineNumber
         put word 4 of tInsertionPoint into tEndLineNumber
         put line tStartLineNumber of tScript into tLine
         
         replace pVarName with tNewName in line tStartLineNumber of tScript
         replace pVarName with tNewName in line tEndLineNumber of tScript
         
         set the itemdelimiter to comma
         put word 3 to -1 of tLine into tOldParams
         put token 1 to -1 of tOldParams into tOldParams
         repeat with x=1 to the number of items in tOldParams
            put x into tParamsArray[x]
         end repeat
         ChangeSignatureInScript pVarName, tNewName, tParamsArray, tScript
         SetScript tScript
         
         if tRenameType is kThisScript then
            -- just this script, so we're done
         else
            -- globally
            put WhereUsed(pVarName, tType) into tList
            repeat for each line tObject in tList
               put the script of tObject into tScript
               -- first see if there is a handler of the same name in the script
               -- if not, then go ahead and change the signature
               -- if so, then we probably don't want to change it.
               --
               -- unless we do, in which case we also need the change the handler declaration
               if ShouldSkipScript?(tScript) then
               else
                  ChangeSignatureInScript pVarName, tNewName, tEmptyArray, tScript
                  SetScript tScript, tObject
               end if
            end repeat
         end if
         unlock screen
      end if
   end if
end RenameHandler

private function ShouldSkipScript? pHandlerName, pScript
   local tTestScript
   local tShouldSkip?
   
   put false into tShouldSkip?
   put pScript into tTestScript
   filter tTestScript with "*" && pHandlerName & "*"
   if tTestScript is not empty then
      repeat for each line tLine in tTestScript
         if word 2 of tLine is pHandlerName then
            put true into tShouldSkip?
            exit repeat
         end if
      end repeat
   end if
   return tShouldSkip?
end ShouldSkipScript?

/**
* RenameVariable
*/
private command RenameVariable pVariableName
   local tRenameType
   local tNewName
   local tScript, tTestForLocal
   local tStartLineNumber, tEndLineNumber
   local tLocalScript
   local tLineCount
   local tObject
   
   if pVariableName is not empty then
      -- default to entire script
      put "This script" into tRenameType
      put CurrentObject() into tObject
      put scriptFromEditor() into tScript
      
      -- see if this is a script-local or handler-local variable
      put filteredScript("local*" & pVariableName, tScript) into tTestForLocal
      
      if tTestForLocal is empty then
         answer "Rename scope" with "This handler only" and "This script" and "Cancel"
         put it into tRenameType
      end if
      if it is not "Cancel" then
         ask "New name for" && pVariableName with pVariableName
         if it is empty or it is pVariableName then
            exit RenameVariable
         else
            put word 1 of it into tNewName
         end if
         set the itemdelimiter to comma
         if tRenameType is "This script" then
            -- entire script
            put 1 into tStartLineNumber
            put tScript into tLocalScript
         else
            -- just this handler
            local tInsertionPoint
            put ContextForCurrentLine() into tInsertionPoint
            put word 3 of tInsertionPoint into tStartLineNumber
            put word 4 of tInsertionPoint into tEndLineNumber
            put line tStartLineNumber to tEndLineNumber of tScript into tLocalScript
         end if
         put 0 into tLineCount
         
         local tShouldProcessLine?
         repeat for each line tLine in tLocalScript
            put true into tShouldProcessLine?
            -- end of handler?
            switch word 1 of tLine
               case pVariableName
                  put false into tShouldProcessLine?
                  break
               case "end"
                  if tRenameType is "This handler only" then
                     put false into tShouldProcessLine?
                  end if
                  break
            end switch
            if tShouldProcessLine? then
               if pVariableName is in tLine then
                  -- ignore string literals
                  replace q(pVariableName) with numtochar(4) in tLine
                  put DoReplace(tLine, pVariableName, tNewName) into tLine
                  replace numtochar(4) with q(pVariableName) in tLine
                  put tLine into line tLineCount+tStartLineNumber of tScript
               end if
            end if
            add 1 to tLineCount -- moved per bn
         end repeat
         
         SetScript tScript
      end if
   end if
end RenameVariable

/**
* DoReplace
*
* wholematches doesn't work with the replace command, so we resort to this
*
* pScript : the text to be manipulated
* pOutgoingString : string to be replaced
* pIncomingString : replacement string
*
* Returns: the string with replacements made
*/
private function DoReplace pScript, pOutgoingString, pIncomingString
   local tWordNumber
   
   put 1 into tWordNumber
   repeat for each word tWord in pScript
      if tWord is pOutgoingString then
         put pIncomingString into word tWordNumber of pScript
      end if
      add 1 to tWordNumber
   end repeat   
   return pScript
end DoReplace

/**
* MoveHandler
*/
private command MoveHandler
   CopyOrMove "Move"
end MoveHandler

/**
* CopyHandler
*/
private command CopyHandler
   CopyOrMove "Copy"
end CopyHandler

/**
* MoveCopy
*/
private command CopyOrMove pMode
   local tInsertionPoint
   local tStartLineNumber, tEndLineNumber
   local tScript, tHandler, tDestinationScript
   local tDestination
   local tObjectID
   local tControlsList
   
   put CurrentObject() into tObjectID
   put ContextForCurrentLine() into tInsertionPoint
   -- get just the handler name
   put word 2 of tInsertionPoint into tHandler
   put pMode && tHandler && "to where?" into field "fldObjects" of stack "Object Selector" of me
   -- get the list of scripts being edited
   -- convert that into a list of mainstacks
   -- list the substacks, cards, and objects
   --put scriptObjectsOfObject(tObjectID) into tControlsList
   put scriptObjectsOfObject() into tControlsList
   put tControlsList into button "btnObjects" of stack "Object Selector" of me
   put empty into tDestination
   modal stack "Object Selector" of me
   put the dialogdata into tDestination
   if tDestination is not empty and tDestination is not "yes" then
      put scriptFromEditor() into tScript
      put word 3 of tInsertionPoint into tStartLineNumber
      put word 4 of tInsertionPoint into tEndLineNumber
      put line tStartLineNumber to tEndLineNumber of tScript into tHandler
      
      -- ensure there's no handler of the same name in the destination script
      local tHandlerName, tTestName
      put line 1 of tHandler into tHandlerName
      if word 1 of tHandlerName is "private" then
         put word 2 to 3 of tHandlerName into tTestName
      else
         put word 1 to 2 of tHandlerName into tTestName
      end if
      
      ## make sure on/command as synonyms are caught
      if word 1 of tTestName is "on" or word 1 of tTestName is "command" then
         if word 1 of tTestName is "on" then
            put cr & "command" && word 2 of line 1 of tTestName after tTestName
         else
            put cr & "on" && word 2 of line 1 of tTestName after tTestName
         end if
      end if
      
      local tDestScript
      put the script of tDestination into tDestScript
      
      ## test for space or return after handlername to exclude partial matches
      ## there is already a space before the handler name
      repeat for each line aHandler in tTestName
         if offset(aHandler & space, tDestScript) is not 0 \
               or offset(aHandler & cr, tDestScript) is not 0 then
            answer "a handler of that name already exists at" && tDestination & cr
            exit CopyOrMove
         end if
      end repeat
      
      -- now we're ready to copy the handler
      try
         edit the script of tDestination
         put scriptFromEditor() & cr & tHandler & cr into tDestinationScript
         SetScript tDestinationScript
         -- see if we should delete the original script lines
         if pMode is "Move" then
            edit the script of tObjectID
            delete line tStartLineNumber to tEndLineNumber of tScript
            SetScript tScript
         end if
      catch e
         answer e
      end try
   end if
end CopyOrMove

/**
* SafeDelete
*/
private command SafeDelete pHandlerName
   local tList
   local tType
   local tLinesToDelete
   local tStartLineNumber, tEndLineNumber
   local tObject
   
   -- see if it's a command or function
   put HandlerType() into tType
   put WhereUsed(pHandlerName, tType) into tList
   if tList is not empty then
      answer "Not safe to delete. Used here:" & cr & tList
   else
      lock screen
      put ContextForCurrentLine() into tLinesToDelete
      put CurrentObject() into tObject
      set the itemDelimiter to comma
      put word 3 of tLinesToDelete into tStartLineNumber
      put word 4 of tLinesToDelete into tEndLineNumber
      delete line tStartLineNumber to tEndLineNumber of field kCodeField of group "Editor" of stack main
      setSEDirtyFlagFor tObject
      unlock screen
   end if
end SafeDelete

/**
* HandlerType
*/
private function HandlerType
   local tTargetLineNumber
   local tLine
   local tType
   local tScript
   
   -- see if it's a command or function
   put word 2 of the selectedline into tTargetLineNumber
   put scriptFromEditor() into tScript
   put line tTargetLineNumber of tScript into tLine
   put word 1 of tLine into tType
   if tType is "private" then
      put word 2 of tLine into tType
   end if
   return tType
end HandlerType

/**
* InsertionPoint
*
* Find where to insert the text at beginning of script
*/
private function InsertionPoint pScript
   local tInsertionPoint
   local tInComment?
   
   put 0 into tInsertionPoint
   put false into tInComment?
   set the itemDelimiter to comma
   if word 1 to -1 of pScript is not empty then
      repeat for each line tLine in pScript
         add 1 to tInsertionPoint
         if token 1 of tLine is empty then
            -- ignore comment lines
            next repeat
         end if
         if tLine begins with "/*" then
            -- try to ignore block comments
            put true into tInComment?
            next repeat
         end if
         if "*/" is in tLine then
            put false into tInComment?
         else
            if tInComment? is false then
               exit repeat
            end if
         end if
      end repeat
   end if
   return tInsertionPoint
end InsertionPoint

private command insertAtStartOfScript pLine, @pScript
   local tInsertionPoint
   
   put InsertionPoint(pScript) into tInsertionPoint
   put pLine & cr before line tInsertionPoint of pScript
   return tInsertionPoint
end insertAtStartOfScript

/**
* ContextForCurrentLine
*
* return the start and end line numbers and the handler name
* for the handler containing the currently selected line
*/
private function ContextForCurrentLine
   local tTarget
   
   lock screen
   focus on field kCodeField of group "Editor" of stack main
   put word 2 of the selectedline into tTarget
   unlock screen
   return ScriptContextForLineNumber(tTarget)
end ContextForCurrentLine

/**
* ScriptContextForLineNumber
*
* return the start and end line numbers and the handler name
* for the handler containing the given line
*/
private function ScriptContextForLineNumber pSelectedLine
   local tHandlerList
   local tObject
   
   -- if the script has been edited by not applied
   -- revavailablehandlers will return wrong information
   put CurrentObject() into tObject
   put availableHandlersOf(tObject) into tHandlerList
   repeat for each line tHandler in tHandlerList
      -- check the start line
      if word 3 of tHandler <= pSelectedLine then
         -- check the end line
         if word 4 of tHandler >= pSelectedLine then
            return tHandler
         end if
      end if
   end repeat
   -- otherwise return the entire script scope
   return "X Script 1 -1"
end ScriptContextForLineNumber

private function extractHandlerTextAtLine pLineNumber, pScript
   local tInsertionPoint, tStartLineNumber, tEndLineNumber
   local tHandler
   
   set the itemdelimiter to comma
   put ScriptContextForLineNumber(pLineNumber) into tInsertionPoint
   replace space with comma in tInsertionPoint
   put item 3 of tInsertionPoint into tStartLineNumber
   put item 4 of tInsertionPoint into tEndLineNumber
   put line tStartLineNumber to tEndLineNumber of pScript into tHandler
   return tHandler
end extractHandlerTextAtLine

function availableHandlersOf pObject
   -- revAvailableHandlers is wrong if there are unapplied edits
   -- and doesn't find duplicate handlers
   -- so we have to roll our own
   local tHandlerList
   local tEditors, tTargetObjects
   local tScript, tHandlers
   local tHandler
   local tHandlerArray
   local tHandlerType
   local tPos
   
   -- see if we've already cached this list
   if sObjectHandlersArray[pObject] is not empty then
      return sObjectHandlersArray[pObject]
   end if
   put revListScriptEditors() into tEditors
   repeat for each line tEditor in tEditors
      -- get a list of the objects being edited in all editors
      dispatch "revSEGetTargetObjects" to group "Editor" of stack tEditor
      put the result after tTargetObjects
      if pObject is among the lines of tTargetObjects then
         put scriptFromEditor(pObject) into tScript
         put tScript into tHandlers
         removeCommentsFrom tHandlers
         replace "command " with "on " in tHandlers
         
         local tHandlerStarts, tLastLineNumber
         -- get 'before' and 'after' handlers
         filter tHandlers with regex pattern "(?i)^[ba][ef][ft].*" into tHandlerStarts
         put 0 into tLastLineNumber
         repeat for each line tLine in tHandlerStarts
            put word 2 of tLine into tHandler
            put lineoffset(tLine, tScript, tLastLineNumber) into tPos
            put tPos + tLastLineNumber into tLastLineNumber
            switch word 1 of tLine
               case "before"
                  put "B" into tHandlerType
                  break
               case "after"
                  put "A" into tHandlerType
                  break
            end switch
            put tHandlerType into tHandlerArray[tHandler][tLastLineNumber]["type"]
            put tLastLineNumber into tHandlerArray[tHandler][tLastLineNumber]["startline"]
            put lineoffset("end" && tHandler, tScript, tLastLineNumber) into tPos
            put tPos + tLastLineNumber into tHandlerArray[tHandler][tLastLineNumber]["endline"]
         end repeat
         
         filter tHandlers with regex pattern "(?i)^(private )?function .*" into tHandlerStarts
         put 0 into tLastLineNumber
         repeat for each line tLine in tHandlerStarts
            if word 1 of tLine is "private" then
               delete word 1 of tLine
            end if
            put word 2 of tLine into tHandler
            put offset("(", tHandler) into tPos
            if tPos > 0 then
               delete char tPos to -1 of tHandler
            end if
            put "F" into tHandlerType
            put lineoffset(tLine, tHandlers, tLastLineNumber) into tPos
            put tPos + tLastLineNumber into tLastLineNumber
            put tHandlerType into tHandlerArray[tHandler][tLastLineNumber]["type"]
            put tLastLineNumber into tHandlerArray[tHandler][tLastLineNumber]["startline"]
            put lineoffset("end" && tHandler, tScript, tLastLineNumber) into tPos
            put tPos + tLastLineNumber into tHandlerArray[tHandler][tLastLineNumber]["endline"]
         end repeat
         
         -- find 'private', 'command' and 'on' handlers
         filter tHandlers with regex pattern "(?i)^[pcogs][rone][im t].*" into tHandlerStarts
         -- we already processed functions
         filter tHandlerStarts without "* function *"
         put 0 into tLastLineNumber
         repeat for each line tLine in tHandlerStarts
            if word 1 of tLine is "private" then
               delete word 1 of tLine
            end if
            put word 2 of tLine into tHandler
            put simpleTypeFromVerboseType(word 1 of tLine) into tHandlerType
            put lineoffset(tLine, tHandlers, tLastLineNumber) into tPos
            put tPos + tLastLineNumber into tLastLineNumber
            put tHandlerType into tHandlerArray[tHandler][tLastLineNumber]["type"]
            put tLastLineNumber into tHandlerArray[tHandler][tLastLineNumber]["startline"]
            put lineoffset("end" && tHandler, tScript, tLastLineNumber) into tPos
            put tPos + tLastLineNumber into tHandlerArray[tHandler][tLastLineNumber]["endline"]
         end repeat
      end if
   end repeat
   
   repeat for each key tHandler in tHandlerArray
      repeat for each key tHandlerLine in tHandlerArray[tHandler]
         put tHandlerArray[tHandler][tHandlerLine]["type"] && \
               tHandler && \
               tHandlerArray[tHandler][tHandlerLine]["startline"] && \
               tHandlerArray[tHandler][tHandlerLine]["endline"] & cr after tHandlerList
      end repeat
   end repeat
   sort lines of tHandlerList by word 1 of each
   sort lines of tHandlerList by word 2 of each
   -- cache the list for future use
   put tHandlerList into sObjectHandlersArray[pObject]
   return tHandlerList
end availableHandlersOf

/**
* WhereUsed
*
* need to return a list containing
* the long objectID
*
* pVariableName, the handler we're about to operate on
*/
private function WhereUsed pVariableName, pType, pReportLocally
   local tScript
   local tObjectList
   local tNumControls
   local tObjectID
   local tMainstack, tStacks
   
   put scriptFromEditor() into tScript
   filter tScript with "private*" & pVariableName & "*"
   
   -- get list of objects and their scripts
   -- get the long id of the object we're working on
   put CurrentObject() into tObjectID
   -- get the stack metadata
   -- get the list of stacks and substacks
   try
      -- get the containing stack from the long id
      put targetStackOf(tObjectID) into tMainstack
      put tMainstack & cr into tStacks
   catch e
      --answer "tObjectID=" & tObjectID & cr & "tMainstack=" & tMainstack
   end try
   put the substacks of stack tMainstack after tStacks
   -- fill the array with stacks and cards
   repeat for each line tStack in tStacks
      if the name of stack tStack is the name of tObjectID then
         if pReportLocally is true then
            put the script of stack tStack into tScript
            if TestScriptForUse(pVariableName, pType, tScript) then
               put the long id of stack tStack & cr after tObjectList
            end if
         end if
      end if
      
      put the number of controls of stack tStack into tNumControls
      repeat with x=1 to tNumControls
         if the name of control x of stack tStack is the name of tObjectID \
               and pReportLocally is not true then
            next repeat
         end if
         put the script of control x of stack tStack into tScript
         if TestScriptForUse(pVariableName, pType, tScript) then
            put the long id of control x of stack tStack & cr after tObjectList
         end if
      end repeat --  with x=1 to tNumControls
   end repeat --  for each line tStack in tStacks
   return tObjectList
end WhereUsed

private function scriptObjectsOfObject --pObjectID
   local tMainstack
   local tTargetObjects
   local tCards
   local tNumControls
   local tControlNamesList, tMainstackList
   local tEditors
   local tObjectArray
   
   -- get a list of all the open script editors
   put revListScriptEditors() into tEditors
   repeat for each line tEditor in tEditors
      -- get a list of the objects being edited
      dispatch "revSEGetTargetObjects" to group "Editor" of stack tEditor
      put the result & cr after tTargetObjects
      repeat for each line tObject in tTargetObjects
         -- get the containing stack from the long id
         put targetStackOf(tObject) into tMainstack
         if tMainstack is not among the lines of tMainstackList then
            put tMainstack & cr after tMainstackList
            put the substacks of stack tMainstack & cr after tMainstackList
         end if
      end repeat
      filter tMainstackList without empty -- bn
      
      local tStackID, tCardID
      put empty into tObjectArray
      repeat for each line tStack in tMainstackList
         -- list the stack itself
         put the long id of stack tStack into tStackID
         put tStack into tObjectArray[tStackID]
         put the cardids of stack tStack into tCards
         repeat for each line tCard in tCards
            put the long id of card id tCard of tStackID into tCardID
            put tCardID into tObjectArray[tStackID][tCard][ID]
            -- list each card in the stack
            put the number of controls of tCardID into tNumControls
            repeat with x=1 to tNumControls
               -- list the long id of each control on the card
               put the long id of control x of tCardID into tObjectArray[tStackID][tCard][x]
            end repeat
         end repeat
      end repeat
   end repeat
   
   -- unwind the array into something an option menu can use
   repeat for each key tStack in tObjectArray
      put the name of tStack & cr after tControlNamesList -- the stack name
      put tab & the name of tStack & cr after tControlNamesList -- the stack name
      repeat for each element tCard in tObjectArray[tStack]
         put tab & the name of tCard[ID] & cr after tControlNamesList
         repeat for each element tControl in tCard
            put tab & tab & the name of tControl & cr after tControlNamesList
         end repeat
      end repeat
   end repeat
   return tControlNamesList
end scriptObjectsOfObject


/**
* TestScriptForUse
*
* Return true if the given handler name is used in the given script
* Return false if there is a private handler with the same name
* Only called from WhereUsed
*/
private function TestScriptForUse pHandlerName, pType, pScript
   local tIsUsed?
   local tWordOffset
   
   put false into tIsUsed?
   set the wholeMatches to true
   if pScript is not empty then
      filter pScript without "end*"
      
      if quote is in pScript then
         removeQuotesFrom pScript
      end if
      replace "command " with "on " in pScript
      filter pScript with " *" & pHandlerName & "*"
      filter pScript without "\blocal\b *" # handle the handler name and local var being the same
      replace "+" with space in pScript
      put replaceText(pScript, "[\[\](),-]", space) into pScript
      if pScript is not empty then
         put wordoffset(pHandlerName, pScript) into tWordOffset
         if tWordOffset is not 0 then
            if char 1 of word tWordOffset of pScript is not quote then
               put true into tIsUsed?
            end if
         end if
      end if -- massaged pScript is not empty
   end if -- pScript is not empty
   return tIsUsed?
end TestScriptForUse

/**
*
*/
private command SetScript pScript, pObject
   local tSelectionPoint
   local tSavedDefaultStack
   
   lock screen
   put the defaultstack into tSavedDefaultStack
   set the defaultstack to main
   if pObject is empty then
      put CurrentObject() into pObject
   end if
   -- set undo restore point
   edit the script of pObject
   Undo.Push pObject
   try
      put the selectedChunk into tSelectionPoint
      StoreScrollsOfCard
      put pScript into field kCodeField of group "Editor"
      dispatch "scriptColorize" to group "Editor" of stack main with "script"
      setSEDirtyFlagFor pObject
      RestoreScrollsOfCard
      if tSelectionPoint is not empty then
         select after tSelectionPoint
      end if
   catch e
      -- this shouldn't happen, so tell the user
      answer "SetScript:" && e & cr & "tSelectionPoint=" & tSelectionPoint
   end try
   set the defaultstack to tSavedDefaultStack
   unlock screen
end SetScript

private command setSEDirtyFlagFor pObject
   put CurrentObject() into pObject
   dispatch "setDirty" to group "Editor" of stack main with pObject, true
   -- call this to fake out the dirty flag... otherwise it's not persistent
   -- this tells the textReplace handler to move nothing starting at char 1
   --
   -- NOTE: textReplace needs the object reference to be in rugged ID form, NOT long id
   --
   dispatch "textReplace" to group "Editor" of stack main with 1, "", "", pObject
end setSEDirtyFlagFor

private function duplicateHandlers --pScript
   local tDuplicates
   local tObject
   local tHandlerList
   local tPreviousLine
   local tType
   
   put CurrentObject() into tObject
   put availableHandlersOf(tObject) into tHandlerList
   repeat for each line tLine in tHandlerList
      if word 1 to 2 of tLine is word 1 to 2 of tPreviousLine then
         put verboseTypeFromSimpleType(word 1 of tLine) into tType
         if word 3 of tPreviousLine & tab & "duplicate" && tType && word 2 of tPreviousLine is not in tDuplicates then
            put word 3 of tPreviousLine & tab & "duplicate" && tType && word 2 of tPreviousLine & cr after tDuplicates
         end if
         put word 3 of tLine & tab & "duplicate" && tType && word 2 of tLine & cr after tDuplicates
      end if
      put tLine into tPreviousLine
   end repeat
   return tDuplicates
end duplicateHandlers

private function verboseTypeFromSimpleType pType
   local tVerboseType
   
   switch pType
      case "G"
         put "getProp handler" into tVerboseType
         break
      case "S"
         put "setProp handler" into tVerboseType
         break
      case "F"
         put "function" into tVerboseType
         break
      default
         put "command" into tVerboseType
   end switch
   return tVerboseType
end verboseTypeFromSimpleType

private function simpleTypeFromVerboseType pType
   local tSimpleType
   
   switch pType
      case "getProp"
         put "G" into tSimpleType
         break
      case "setProp"
         put "S" into tSimpleType
         break
      default
         put "M" into tSimpleType
   end switch
   return tSimpleType
end simpleTypeFromVerboseType
/**
-- in this script:
-- find unused globals
-- find unused script locals
-- find unused constants
-- find unused private handlers... not

-- globally:
-- find unused non-private handlers
*/
private command FindOrphans pObject
   local tScript
   local tOrphanList, tUndeclaredList
   local tLineNumber
   local tPutLine
   
   lock screen
   if pObject is empty then
      put CurrentObject() into pObject
   end if
   put scriptFromEditor() into tScript
   
   put ListOrphansOfType("global", tScript) after tOrphanList
   put ListOrphansOfType("local", tScript) after tOrphanList
   put ListOrphansOfType("constant", tScript) after tOrphanList
   put listParamsIn(pObject) after tOrphanList
   
   -- do the global thing
   put globalOrphansOf(pObject) after tOrphanList
   
   -- find undeclared variables if explicitVars is false
   local tUndeclared
   put listUndeclaredVariablesIn(tScript) into tUndeclared
   
   -- find leftover "put <xyz>" and "put <xyz> into msg"
   put 1 into tLineNumber
   repeat for each line tLine in tScript
      switch token 1 of tLine
         case "put"
            removeCommentsFrom tLine
            local tLineAdd
            put tLineNumber into tLineAdd
            repeat while char -1 of word -1 of tLine is "\"
               add 1 to tLineAdd
               put line tLineAdd of tScript into word -1 of tLine
               removeCommentsFrom tLine
            end repeat
            filter tLine with "* [abi][fen][tf][eo][r ]*" into tPutLine
            if tPutLine is not empty then
               if token -1 of tLine is not among the items of "msg,message" then
                  break
               end if
            end if
            -- just fall through here
         case "breakpoint"
            put tLineNumber & tab & "orphan" && word 1 to -1 of tLine & cr after tOrphanList
            break
      end switch
      add 1 to tLineNumber
   end repeat
   
   put duplicateHandlers() after tOrphanList
   
   displayUndeclaredVars tUndeclared
   displayOrphans tOrphanList, tUndeclaredList is not empty
   unlock screen
end FindOrphans

private command displayUndeclaredVars pUndeclaredList
   -- see if there are any present then
   if pUndeclaredList is empty then -- nothing to see here
   else
      lock screen
      -- place the undeclared variables on the Undeclared card
      put pUndeclaredList into field "fldUndeclared" of card "Undeclared" of me
      set the visible of button "btnUndeclared" of card "Orphans" of me to true
      unlock screen
   end if
end displayUndeclaredVars

private command displayOrphans pOrphanList, pUndeclaredVarsExist
   if pOrphanList is not empty or pUndeclaredVarsExist then
      lock screen
      -- group by type rather than sorting by line number
      --sort numeric pOrphanList
      sort lines of pOrphanList by item 2 of each
      put pOrphanList into field "fldOrphanList" of card "Orphans" of me
      palette me
      set the visible of me to true
      if pOrphanList is not empty then
         go card "Orphans" of stack self
      else
         go card "Undeclared" of stack self
      end if
      unlock screen
   end if
end displayOrphans

private function listUndeclaredVariablesIn pScript
   local tUndeclared, tVariable
   local tGlobals, tLocals
   local tLineNumber
   local tCurrentHandler
   local tVariables
   
   lock screen
   set the visible of button "btnUndeclared" of card "Orphans" of me to false
   dispatch "revSEGetPreference" to stack "revseutilities"  with "explicitVariables"
   if the result is true then
   else
      -- put the undeclared variables into tUndeclared
      put 1 into tLineNumber
      set the itemdelimiter to comma
      repeat for each line tTest in pScript
         if char 1 of tTest is not space then
            put empty into tCurrentHandler
         end if
         switch token 1 of tTest
            case "global"
               put word 2 to -1 of tTest into tVariables
               repeat for each item tVar in tVariables
                  put tCurrentHandler && word 1 of tVar & cr after tGlobals
               end repeat
               break
            case "local"
               put word 2 to -1 of tTest into tVariables
               repeat for each item tVar in tVariables
                  put tCurrentHandler && word 1 of tVar & cr after tLocals
               end repeat
               break
            case "repeat"
               -- find the variable here:
               -- repeat for each <thing> variable
               if token 2 to 3 of tTest is "for each" then
                  put tCurrentHandler &&  token 5 of tTest & cr after tLocals
               end if
               break
            case "private"
               delete token 1 of tTest
            case "on"
            case "command"
            case "function"
            case "before"
            case "after"
            case "getProp"
            case "setProp"
               put token 2 of tTest into tCurrentHandler
               repeat for each item tParam in token 3 to -1 of tTest
                  put word 1 of tParam into tParam
                  if char 1 of tParam is "@" then
                     delete char 1 of tParam
                  end if
                  put tCurrentHandler && tParam & cr after tLocals
               end repeat
               break
            case "put"
               filter tTest without "* into the *"
               if token -2 of tTest is in "into,before,after" then
                  put token -1 of tTest into tVariable
                  if tVariable is among the items of "msg,message" then
                     break
                  end if
                  if tCurrentHandler && tVariable is among the lines of tGlobals \
                        or space & tVariable is among the lines of tGlobals \
                        or tCurrentHandler && tVariable is among the lines of tLocals \
                        or space & tVariable is among the lines of tLocals then
                     break
                  end if
                  if tCurrentHandler && tLineNumber && tVariable is not among the lines of tUndeclared then
                     put tCurrentHandler && tLineNumber && tVariable & cr after tUndeclared
                  end if
               end if
               break
         end switch
         add 1 to tLineNumber
      end repeat
   end if
   unlock screen
   return tUndeclared
end listUndeclaredVariablesIn

private command removeCommentsFrom @pText
   local tHowManyLines
   local tSubText
   local tCRs
   
   removeQuotesFrom pText
   
   -- remove block comments
   
   -- remove quoted literal slash asterisk and quoted asterisk slash
   -- restore them later
   --put quote & "/*" & quote into tQuoteSlashStart
   --put quote & "*/" & quote into tQuoteSlashEnd
   
   --replace tQuoteSlashStart with "slashAsterix" in pText
   --replace tQuoteSlashEnd with "obelixSlash" in pText
   set the lineDelimiter to "/*"
   set the itemDelimiter to "*/"
   put the number of lines of pText into tHowManyLines
   if tHowManyLines > 1 then
      repeat with i = 2 to tHowManyLines
         put item 1 of line i of pText into tSubText
         
         -- replace slash comments with empty lines
         --repeat for each char aChar in tSubText
         repeat for each char aChar in item 1 of line i of pText
            if aChar is cr then
               put cr after tCRs
            end if
         end repeat
         put tCRs into item 1 of line i of pText
         put "" into tCRs
      end repeat
      replace "/*" with empty in pText
      replace "*/" with empty in pText
      --replace "slashAsterix" with tQuoteSlashStart in pText
      --replace "obelixSlash" with tQuoteSlashEnd in pText
   end if
   
   -- remove single-line comments
   put replacetext(pText, "#.*", " ") into pText
   put replacetext(pText, "--.*", " ") into pText
   put replacetext(pText, "//.*", " ") into pText
end removeCommentsFrom

private command removeQuotesFrom @pText
   --local tSavedItemDelimiter
   local tNoItems
   
   --put the itemDelimiter into tSavedItemDelimiter
   set the itemDelimiter to quote
   put the number of items in pText into tNoItems
   if tNoItems > 1 then
      
      local i
      put 0 into i
      repeat for each item tItem in pText
         if i mod 2 = 0 then 
            put empty into item i of pText
         end if
         add 1 to i
      end repeat
      
   end if
   --set the itemDelimiter to tSavedItemDelimiter
end removeQuotesFrom

/**
* listOrphansOfType
* function
*  pType : "global", "local", "constant", "private"
*  pScript : the script we're working with
* returns
*  tOrphanList
*/
private function listOrphansOfType pType, pScript
   local tOrphanList
   local tFilteredScript, tConstantList
   
   -- look for declarations
   put filteredScript(pType && "*", pScript) into tFilteredScript
   if pType is "constant" then
      repeat for each line tLine in tFilteredScript
         put word 2 of tLine & cr after tConstantList
      end repeat
      put tConstantList into tFilteredScript
   end if
   -- see if there's anything to work with
   local tOffsetLine
   if tFilteredScript is not empty then
      local tPos
      repeat for each key tKey in sScriptArray
         put sScriptArray[tKey] into tLine
         put tLine into tOffsetLine
         delete word 1 of tLine -- should be pType
         -- remove initialization value
         put offset("=", tLine) into tPos
         if tPos > 0 then
            delete char tPos to -1 of tLine
         end if
         
         local tScope
         put extractHandlerTextAtLine(tKey, pScript) into tScope
         filter tScope without "*" & pType & " *"
         repeat for each item tVariable in tLine
            if word 1 of tVariable is not among the tokens of tScope then
               put tKey & tab & "unused" && pType && tVariable & cr after tOrphanList
            end if
         end repeat
      end repeat
   end if
   
   sort tOrphanList
   return tOrphanList
end listOrphansOfType

private function listParamsIn pObject
   local tOrphanList
   local tHandlerList
   local tLineNumber
   local tScript
   local tDeclaration
   local tParameter
   local tScope
   
   put availableHandlersOf(pObject) into tHandlerList
   put scriptFromEditor() into tScript
   repeat for each line tHandlerDetails in tHandlerList
      put word 3 of tHandlerDetails into tLineNumber
      put token 1 to -1 of line tLineNumber of tScript into tDeclaration
      if "private" is word 1 of tDeclaration then
         delete word 1 of tDeclaration
      end if
      delete word 1 to 2 of tDeclaration
      replace comma with empty in tDeclaration
      replace "@" with empty in tDeclaration
      if tDeclaration is not empty then
         put extractHandlerTextAtLine(tLineNumber, tScript) into tScope
         repeat for each word tParameter in tDeclaration
            if not TestScriptForUse(tParameter, "param", tScope) then
               put tLineNumber & tab & "unused parameter" && tParameter & cr after tOrphanList
            end if
         end repeat
      end if
   end repeat
   return tOrphanList
end listParamsIn

/**
* globalOrphansOf
*
* Find unused commands and functions
* function
*  pObject
* returns
*  tOrphanList
*/
private function globalOrphansOf pObject
   local tHandlerList
   local tHandler, tType
   local tOrphanList
   local tAllMessagesA
   
   put getIDEMessages("message") into tAllMessagesA
   
   put availableHandlersOf(pObject) into tHandlerList
   repeat for each line tHandlerDetails in tHandlerList
      if tAllMessagesA[word 2 of tHandlerDetails] or word 2 of tHandlerDetails begins with "rev" then
         next repeat
      end if
      
      put "function" into tType
      switch char 1 of tHandlerDetails
         case "P"
            if char 2 of tHandlerDetails is "F" then
               break
            end if
         case "G"
            put "getProp handler" into tType
            break
         case "S"
            put "setProp handler" into tType
            break
         case "M"
            put "command" into tType
            break
      end switch
      put word 2 of tHandlerDetails into tHandler
      if WhereUsed(tHandler, tType, true) is empty then
         put word 3 of tHandlerDetails & tab & "unused" && tType && tHandler & cr after tOrphanList
      end if
   end repeat
   return tOrphanList
end globalOrphansOf

private function getIDEMessages pElementType
   local tMessagesA, tAllMessagesA
   
   -- bernd's discovery
   put ideDocsFetchLCSElementsOfType(pElementType) into tMessagesA
   repeat for each key aKey in tMessagesA
      put tMessagesA[aKey]["display Name"] & cr after tAllMessagesA
   end repeat
   split tAllMessagesA by return as set
   return tAllMessagesA
end getIDEMessages

/**
* filteredScript
*/
private function filteredScript pType, pScript
   local x
   local tScript
   
   delete variable sScriptArray
   put 1 into x
   removeCommentsFrom pScript
   repeat for each line tLine in pScript
      if word 1 of tLine begins with word 1 of pType then
         put tLine into sScriptArray[x]
         put tLine & cr after tScript
      end if
      add 1 to x
   end repeat
   return tScript
end filteredScript

local sEditObjects
private command StoreScrollsOfCard
   local tCard
   
   lock screen
   put the short name of this card into tCard
   put the vscroll of field kCodeField of card tCard into sEditObjects["card"][tCard]["vScroll"]
   put the hscroll of field kCodeField of card tCard into sEditObjects["card"][tCard]["hScroll"]
   unlock screen
end StoreScrollsOfCard

private command RestoreScrollsOfCard
   local tCard
   
   lock screen
   put the short name of this card into tCard
   set the vscroll of field kCodeField of card tCard to sEditObjects["card"][tCard]["vScroll"]
   set the hscroll of field kCodeField of card tCard to sEditObjects["card"][tCard]["hScroll"]
   dispatch "matchScrolls" to field kCodeField of card tCard
   unlock screen
end RestoreScrollsOfCard

/**
* Return the mainstack of the given object
*/
private function targetStackOf pWhich
   local tParse
   local tStackName
   
   if pWhich is not empty and there is a pWhich and word 1 of pWhich is not "the" then
      put the long id of pWhich into tParse
   else
      put the long id of the target into tParse
   end if
   get wordoffset("stack", tParse)
   
   put word (it) to (it+1) of tParse into tStackName
   put the short name of tStackName into tStackName
   return the mainstack of stack tStackName
end targetStackOf

--> Undo support

local sUndoPointArray

/**
* Undo.Reset
*
* We are saving a stack.
* Find all the undo elements for this stack
* and set a "save" marker for each one.
* That way when we try to undo past the save
* we can bring up a comfirmation dialog.
*
* pStack contains the short name of the stack
*/
private command Undo.Reset pStack
    local tKeys
    
    -- pStack contains the short name of the stack
    put the long id of pStack into pStack
    put the keys of sUndoPointArray into tKeys
    repeat for each line tObject in tKeys
        -- see if we're editing an object of the stack we're saving
        if word -1 of pStack is word -1 of tObject then
            -- set the save pointer if so
            Undo.SetSavePointer tObject
        end if
    end repeat
end Undo.Reset

/**
* Undo.Retrieve
*
* Retrive an element from the sUndoPointArray
*/
private function Undo.Retrieve pObject, pCount
   local tData
   
   set the itemdelimiter to comma
   put sUndoPointArray[pObject]["data"][pCount] into tData
   return tData
end Undo.Retrieve

/**
* Undo.Store
*
* Store an element into the sUndoPointArray
*/
private command Undo.Store pObject, pCount, pValue
   set the itemdelimiter to comma
   put pValue into sUndoPointArray[pObject]["data"][pCount]
   if pCount is among the items of "count,save" then
   else
      put the selectedChunk into sUndoPointArray[pObject]["selection"][pCount]
   end if
end Undo.Store

private function Undo.SelectPointer pObject, pCount
   local tData
   
   put sUndoPointArray[pObject]["selection"][pCount] into tData
   return tData
end Undo.SelectPointer

/**
* UndoPointer
*
* Return the undo stack index
*/
private function Undo.Pointer pObject, pShouldCheckSave
   local tCount, tSave
   
   if pShouldCheckSave then
      put Undo.Retrieve(pObject, "save") into tSave
   end if
   put Undo.Retrieve(pObject, "count") into tCount
   if tCount is empty then
      put 0 into tCount
   end if
   if tSave is not empty then
      if tSave > tCount then
         answer "You are trying to undo code that has been saved to disk. Do you want to do this?" with "Yes" and "No"
         if it is not "Yes" then
            put -1 into tCount
         end if
      end if
   end if
   return tCount
end Undo.Pointer

/**
* Undo.SetPointer
*
* @pNewCount : index value for this type of undo action
*/
private command Undo.SetPointer pObject, pNewCount
   Undo.Store pObject, "count", pNewCount
end Undo.SetPointer

/**
* Undo.SetPointer
*
* @pNewCount : index value for this type of undo action
*/
private command Undo.SetSavePointer pObject
   Undo.Store pObject, "save", Undo.Retrieve(pObject, "count")
end Undo.SetSavePointer

/**
* Undo.Push
*
* Increment the index pointer (++push)
* Then save the current script for undoing later on
*/
private command Undo.Push pObject
   local tCount
   
   put CurrentObject() into pObject
   put the long id of pObject into pObject
   put Undo.Pointer(pObject, false)+1 into tCount
   Undo.Store pObject, tCount, compress(scriptFromEditor())
   Undo.SetPointer pObject, tCount -- bump the index pointer
end Undo.Push

/**
* Undo.Pop
*
* undo the last refactor command
* Retrieve the current stored data
* Decrement the index pointer afterwards (pop--)
*/
private command Undo.Pop pObject, pFunc
   local tCount
   local tSavedUndo
   local tSuccess
   
   lock screen
   -- retrieve the current pointer
   put CurrentObject() into pObject
   put the long id of pObject into pObject
   put Undo.Pointer(pObject, true) into tCount
   if tCount > 0 then
      -- see if we're at the top of the stack
      put Undo.Retrieve(pObject, tCount+1) into tSavedUndo
      -- if so, save the current state so we can redo
      if tSavedUndo is empty then
         Undo.Store pObject, tCount+1,  compress(scriptFromEditor())
      end if
      -- retrieve the stored data
      put Undo.Retrieve(pObject, tCount) into tSavedUndo
      
      if tSavedUndo is not empty then
         --dispatch pFunc to the target with pObject, tCount, tSavedUndo
         Undo.RestoreScript pObject, tCount, tSavedUndo
         -- decrement the stack pointer
         Undo.SetPointer pObject, tCount-1
         put true into tSuccess
      end if
   end if
   unlock screen
   if tSuccess then
   else
      switch tCount
         case 0
            -- at bottom of undo stack
            answer "nothing to undo"
            break
         case -1
            -- not undoing past last save
            break
         default
      end switch
   end if
end Undo.Pop

/**
* RedoRefactor
*
* the oops command
* Increment the index pointer (++redo)
* Retrieve the stored data at that index
*/
private command DoRedo pObject, pFunc
   local tCount
   local tSavedUndo
   local tSuccess?
   
   put false into tSuccess?
   lock screen
   -- increment the stack pointer
   put CurrentObject() into pObject
   put Undo.Pointer(pObject, false)+2 into tCount
   put Undo.Retrieve(pObject, tCount) into tSavedUndo
   if tSavedUndo is empty then
      subtract 1 from tCount
      put Undo.Retrieve(pObject, tCount) into tSavedUndo
   end if
   
   if tSavedUndo is not empty then
      dispatch pFunc to the target with pObject, tCount, tSavedUndo
      -- store the new stack pointer
      Undo.SetPointer pObject, tCount-1
      put true into tSuccess?
   end if
   unlock screen
   if tSuccess? then
   else
      answer "nothing to redo @" && tCount
   end if
end DoRedo

private command Undo.RestoreScript pObject, tCount, pScript
   local tSelection
   
   StoreScrollsOfCard
   
   SetScript decompress(pScript), pObject
   RestoreScrollsOfCard
   -- retrieve the previous selection
   put Undo.SelectPointer(pObject, tCount) into tSelection
   if tSelection is not empty then
      select tSelection
   end if
end Undo.RestoreScript

private function CurrentObject --pCard
   local tObject
   
   if glx2IsInUse() then
      dispatch function "CurrentObject" to stack main
   else
      dispatch "getCurrentTab" to group "Script Tabs" of stack main
   end if
   -- NOTE: getCurrentTab returns the object reference as a rugged ID
   put the result into tObject
end CurrentObject

private function glx2IsInUse
   return kCodeField is "code storage"
end glx2IsInUse

-- if the stackrunner is not being used, then ensure *something* works
-- note that empty is true
command assertIsTrue pExpression
   return pExpression is not false
end assertIsTrue


on localNotificationReceived pMessage
   
end localNotificationReceived
