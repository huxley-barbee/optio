# Overview

Optio is a framework to create terminal menus in bash. 

Optio supports:

- executing arbitrary bash scriptlets, 
- submenus, 
- remembering the user's previous responses,
- and a locked shell.

Download Optio from <https://bitbucket.org/barbee/optio/downloads>.

Optio is licensed under [Mozilla Public License v 2.0](http://mozilla.org/MPL/2.0/)

Optio is written by [JH Barbee](http://www.linkedin.com/in/jhbarbee)

# Version

The current version is 1.2.

# Platforms

Optio runs on any platform that has bash v3.

# Command Line Options

```

./optio.sh [-h] [-d] [-v] [-V] [-c] [-z] [-s <state file>] [-f <config file>]
    -h Prints help
    -d Debug
    -v Verbose
    -c Disable Control+C
    -z Disable Control+Z
    -s Specifies which state file to use
    -f Specifies which config file to use
    -V Prints version information

```

The simplest usage is to run Optio without any arguments.

To lock the user into the shell, add the arguments: *-c* and *-z*.

To debug your menus, add the arguments: *-d* and *-v*.

By default, Optio uses the configuration file **optio.conf** in the current working directory. To override this, use the *-f* option.

Optio provide an API to query the user for yes-or-no or free-form responses. These responses are saved in a state file, from which Optio will provide default answers for iterations of that menu item. By default, the state file is **.optio.state** in the current working directory. To override this, use the *-s* option.

# Examples

Here is what users see with the sample menu that ships with Option.

```
Optio Demonstration Terminal Menu

1) Write Everything To Disk	           5) Edit A File
2) Disk Space			               6) Process Count
3) List Users			               7) Network Menu
4) Display Messages From Other Users  8) Exit
Please make a selection > 
```

### Option 1 
Runs **sudo sync** and immediate return to this menu.

### Option 2

Runs **df** followed by calling the Optio API call **optioHitContinue**

```
Optio Demonstration Terminal Menu

1) Write Everything To Disk	           5) Edit A File
2) Disk Space			               6) Process Count
3) List Users			               7) Network Menu
4) Display Messages From Other Users  8) Exit
Please make a selection > 2
Filesystem                        512-blocks       Used Available Capacity   iused    ifree %iused  Mounted on
/dev/disk0s2                      1463469952 1012612952 450345000    70% 126640617 56293125   69%   /

Please hit enter to continue.
```

### Option 3

Runs cat /etc/passwd | less.

### Option 4

Asks the user a yes or no question using the API call **optioAskYesNo**.

```
Optio Demonstration Terminal Menu

1) Write Everything To Disk	           5) Edit A File
2) Disk Space			               6) Process Count
3) List Users			               7) Network Menu
4) Display Messages From Other Users  8) Exit
Please make a selection > 4
Would you like messages from other users?  [y/N] 
```

Notice that the N is capitalized. This is the default response if the user simply hits enter. That value, N, is read from the state file.

Based on the user's response, the scriptlet will run either **mesg y** or **mesg n**.

### Option 5 

Prompts the user for a free-form response, using the API call **optioAskValue**.

Optio Demonstration Terminal Menu

```
Optio Demonstration Terminal Menu

1) Write Everything To Disk	           5) Edit A File
2) Disk Space			               6) Process Count
3) List Users			               7) Network Menu
4) Display Messages From Other Users  8) Exit
Please make a selection > 5
Which file would you like to edit? [myfile.txt] 
```

Notice that there is a default value of *myfile.txt*. This is the default response if the user simply hits enter. That value, *myfile.txt*, is read from the state file.

### Option 6

Bring up the network submenu.

```
Optio Demonstration Terminal Menu

1) Netstat
2) Back
Please make a selection > 
```
### Option 7

There significance of this option is that it calls into the scriptlet library, which will be discussed more in the Configuration section.

```
Optio Demonstration Terminal Menu

1) Write Everything To Disk	           5) Edit A File
2) Disk Space			               6) Process Count
3) List Users			               7) Network Menu
4) Display Messages From Other Users  8) Exit
Please make a selection > 5
Which file would you like to edit? [myfile.txt] 
```

### Option 8

Exits Optio.

# Configuration

The configuration file is the heart of Optio. This is where you specify you menus, menu items, and your scriptlets.

```
#!shell
# Any line that starts with # is a comment. It is ignored.
```

Text to show at the top of the menu.

```
#!shell
OPTIO_BANNER="Optio Demonstration Terminal Menu"
```

Text to show at the bottom of the menu.

```
#!shell
OPTIO_PROMPT="Please make a selection > "
```

Text to show for the menu item to back to the previous menu.

```
#!shell
OPTIO_BACK="Back"
```

Text to show for the optioHitContinue api call.

```
#!shell
OPTIO_CONTINUE="Please hit enter to continue."
```

How many lines to save in the history.

```
#!shell
OPTIO_STATE_LIMIT=100
```

What is considered yes, in uppercase.

```
#!shell
OPTIO_YES_LOWER="y"
```

What is considered yes, in lowercase.

```
#!shell
OPTIO_YES_UPPER="Y"
```

What is considered no, in uppercase.

```
#!shell
OPTIO_NO_LOWER="n"
```

What is considered yes, in lowercase.

```
#!shell
OPTIO_NO_UPPER="N"
```

@@@ means the end of the global variable section.

```
@@@
```

The next section is the menu configuration.

If the line starts with =, it means a new menu. The
top-level menu MUST be called "root".

```
= root
```

If a line starts with +, it means a new menu item.
Any line that follows a menu item name is the command
to run when the user chooses that item.
This command will run and immediately re-display the
menu choices.

```
#!shell
    + Write Everything To Disk
        sudo sync
```

If you want to run a command and give the user a chance
to see the output, follow the command with the **optioHitContinue**
API call.

```
#!shell
    + Disk Space
        df
        optioHitContinue
```

You can run multiple commands for each menu item.

```
#!shell
    + List Users
        cd /etc
        cat passwd | awk -F: '{print $1}' | less
```

If you want the user to answer a yes/no question, use the **optioAskYesNo** API call. In this example, the user's response will be recorded in $mesgYesNo

```
#!shell
    + Display Messages From Other Users
        optioAskYesNo "Would you like messages from other users?" mesgYesNo
        if test $mesgYesNo;
        then
            mesg y
        else
            mesg n
        fi
```

If you want to get free-form input from the user, use the optioAskValue API call. In this example, the user's response will be recorded in $fileToEdit

```
#!shell
    + Edit A File
        optioAskValue "Which file would you like to edit?" fileToEdit
        vi $fileToEdit
```

This command includes a call into the scriplet library function **processCount**. See below for more information on the scriptlet library.

```
#!shell
    + Process Count
        echo -n "There are "
        processCount
        echo " processes."
        optioHitContinue
```

If a command starts with "menu:", optio will open a submenu.

```        
    + Network Menu
        menu:network
```

If a command is "optioExit", optio exit.

```
    + Exit
        optioExit
```

This is a submenu. Notice that we do not need to configure a "back"
menu item. This is already taken care of by Optio.

```
= network
    + Netstat
        netstat
```

@@@ means the end of the menu item section.

```
@@@
```

The next section is the scriptlet library. Add any valid bash script in here. It will be *source*d each time before Option evaluates a menu item command. This particular function *processCount* is used by option 7 above.

```
#!shell
function processCount() {
    echo -n `ps ax | wc -l`
}
```


# Installation

1. Download the Option package from <https://bitbucket.org/barbee/optio/downloads>.
2. Unzip.
3. Copy to wherever it is appropriate.
4. Add optio.sh's directory to your $PATH.

# Issues

Please visit the project home page at  <https://bitbucket.org/barbee/optio> to file a bug.
