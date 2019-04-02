# revRefactor
Refactoring support for the LiveCode Script Editor

    Brings refactoring support to the LiveCode Script Editor.
    Place the plugin into your user Plugins folder.
    After launching the script editor there will be a new Refactoring menuItem in the Edit menu.
    The Refactoring menuItem will also appear in the contextual menu of the Script Editor.
    The Refactoring menu is inspired by the JetBrains refactoring support in RubyMine, etc.

If you just want to download the Plugin itself, it's now in the "Plugin" folder.
You don't need all the script files unless you want to submit pull requests.

### Rename Handler
Allows you to rename in just the current script or all scripts in the stack.

### Rename Variable
Both Rename Handler and Rename Variable change all uses of the object.

### Convert Literal To Constant
Creates a constant for the selected literal value.

For instance, converts the string literal "hello" to

    constant kHello = "hello"

and changes all references of "hello" to use kHello, i.e.,

      put kHello into tVariable

instead of

      put "hello" into tVariable

### Change Signature
Change the parameter list for a command or function.
For instance, change "myCommand pKey" to "myCommand pKey, pValue"
Modifying parameters will modify calls to the handler in all scripts in the stack.

### Safe Delete
Only deletes the handler/variable if nothing is using it.
Otherwise you get a warning specifying where it's used.

### Move Handler To
### Copy Handler To
These allow you to select a new home for the selected handler.

### Create Getter and Setter
Allow external access to a script local variable.
The handlers will be named after the variable name:

    local ArrayName
    becomes
      command setArrayNameTo pValue
    and
      function ArrayName()

### Add Documentation
Creates documentation for a handler in the form

    /**
    * HandlerName
    * parameters
    * Returns (if a function)
    * returnValues
    */

The documentation format is stored as a custom property template and can be modified if desired.

### Add Test
Adds a template unit test for the selected handler to a file in the same folder as the stack.
The file has the same name as the stack with the ".tests" extension.
The tests file is intended to be run using Ah, Software's TestRunner unit testing stack.
The unit test format is stored as a custom property template.
Modifying it will probably cause it to cease functioning.

### Convert Global To
* Script Local
* Getter and Setter
* Property

### Convert Variable To
* Script Local
* Parameter
* Property

### Extract To
Creates a new handler from the selected block of code in the current script.

### Find Orphan Code
Displays a list of unused local variables and uncalled handlers.
Double-click a list item to select it in the script editor.

### Undo Last Refactor
There's a full undo first-in-last-out stack mechanism for those oops moments.
Issues a warning if you attempt to undo changes already saved to disk.

### Go Back (contextual menu only)
Not strictly part of a refactoring process, but since I was reworking the Edit menu anyway...
After a "Go to definition" call, this gets you back to where you were.

### Known issues

If you have a handler with the same name in multiple scripts in a stack
and you change the signature of the handler for multiple scripts, the handler definitions
in scripts other than the original won't be changed. i.e.,

original script:

    on myHandler pName
    end myHandler

    myHandler "hello"

script of a different object:

    on myHandler pName
    end myHandler

    myHandler "hello"

adding a parameter becomes

original script:

    on myHandler pName, pValue
    end myHandler

    myHandler "hello", pValue

script of a different object:

    on myHandler pName -- * not changed
    end myHandler

    myHandler "hello", pValue

I don't presently have a way around this, and haven't decided whether it's a good idea or not.

    
