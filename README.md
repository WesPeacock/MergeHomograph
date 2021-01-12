# Merge Homographs 
This repository contains a *perl* script to merge homograph pairs in a FLEx project that have identical definitions. It also has a *bash* script to extract the FLEx project from a project backup, run the *perl* script on project and put it back in the  backup.

If the sense of one of the pairs is simple (has only a single definition; no other fields) that sense will be deleted. This is a simple way of merging the two senses.

The two complex form entries will be merged into a single one with two components, one from each of the homographs.

Entries with two homographs but are not processed for some reason are logged in an error file.

Before running the script you have to:

* Sort the project.

  * This doesn't affect how the entries are processed, but does change the order of the error and log messages.

* Optionally filter the project to ignore entries you don't want merged.

* Back up the project, and copy the backup file to your working directory.

* Export the project to a LIFT file.

  * If you have a filter, use the Filtered Project LIFT export.

  * The LIFT export normally exports to its own directory. Copy the *.lift* file from that directory to your working directory.

  * If you need to, change the LIFT file name in line in the *.ini* file. It's on a line that looks like this:

    ```
    liftfilename=all.lift
    ```

### Bugs and Enhancements

#### Bugs

* When entry #1 & #2 are merged. The resulting merged entry is given a homograph #0. If homograph #3 exists this will be incorrect and I don't know what that means. The script checks the LIFT file for the existence of #3, but that may have been filtered or edited out after it was created.

#### Possible Future Enhancements

##### "Force" mode using a flag field

* The script currently ignores homograph sets that have more than two homographs or where definitions differ. Here's a scheme for a "force" mode that has a more nuanced approach.  Note that the two modes are not  mutually exclusive. You could run the basic mode to catch most of the merges and then the "force" mode to handle the residue.

  * ```
    You'd use the Bulk Edit Click Copy feature to set a flag field.

    There's a sample screenshot below. It shows the project filtered by a regular expression on the homograph number and selecting complex forms that have a component. For the entries to be merged the user has click-copied the homograph numbers into the flag field. The user has added an asterisk to one of the flag fields to indicate that it has the definition that will be used for the merged entry.

    Create the LIFT file by filtering on the flag field before export. The resulting LIFT file would have just the entries to be merged. The "force" mode would read the LIFT file for the homographs and use the starred entry for the definition for the merged entry. In the Click-copy bulk edit, if you change the Target Field to the definition, you can edit the definition on the fly as well.

    This enhancement would make selecting the entries fairly quick, but still under the control of a human editor.
    ```

  * ![Click Copy Example](ClickCopyExample.png?raw=true "Click Copy Example")

  ##### Fuzzy comparison

* Could do some sort of "fuzzy" comparison on definition that ignores some punctuation.

  * ```
    E.g. find a way of comparing the following two entries to be the same:
    -bọ̀ ọbọ̀  Won't process. Definitions differ:
            1-"avenge; revenge"
            2-"avenge; revenge:"
    ```

  * This might be done by modifying the definition fields in the LIFT file. The LIFT file is used for selecting the entries to be merged but nothing in the LIFT file gets written back into the project.

    * ```
      WSL bash commands to delete a trailing colon in a file named all.lift:
      $ cp all.lift all.org
      $ dos2unix <all.org | perl -pE 'chomp if /<def/;' | perl -pE 's#\:</text#</text#  if /<definition/;'>all.lift
      ```

      

### How It Works

#### The runmrghmpair.sh bash script

The wrapper script,  **runmrghmpair.sh**:

* Extracts the *.fwdata* file from the backup in the working directory.
* Modifies the *.ini* file so that the perl script will work on the extracted *.fwdata* file.
* Runs the  *mrghmpair.pl* to create a modified *.fwdata* file.
* Puts the resulting *.fwdata* file back into the backup.

#### The mrghmpair.pl perl script

The perl script, **mrghmpair.pl**:

* reads .fwdata file
* reads the LIFT file for all the homographs numbered as #2 and processes each one.
* The below error conditions refer to the LIFT file, not the *.fwdata* file. The LIFT file can been modified after export to change the condition, in which case the *.fwdata* file is processed anyway. See the section above for an example of this.
* Working from the LIFT file, the script ignores the entry and prints and error message to the log if:
  * a homograph #3 exists
  * a homograph #1 doesn't exist
  * both homograph #1 & #2 must have only one sense
  * both homograph #1 & #2 must have only one component lexeme
  * either homograph #1 or #2 have a Import  or sense level Import Residue
  * either homograph #1 or #2 have missing definition
  * homograph #1 & #2  have different definitions.
* Entry #2 is merged into Entry #1 in the FWdata file
  * The sense from Entry #2 becomes the 2nd sense
* If the sense of  LIFT Entry #1 has only 1 subfield i.e. definition
  * delete that sense
* else if the sense of  LIFT Entry #2 has only 1 subfield i.e. definition
  * delete that sense
* else flag no simple sentences to the Log file
* Add the component from the second EntryRef to the first EntryRef
* Delete the second EntryRef
* When all the homograph #2 entries have been processed, write out the FWdata file.