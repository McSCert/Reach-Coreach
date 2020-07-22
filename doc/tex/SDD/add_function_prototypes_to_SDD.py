# This script copies and pastes the function prototypes / class definitions and
# descriptions of the MATLAB functions/classes used for a tool into a 
# corresponding latex document.
# It also maintains the MATLAB format while pasting the information, and
# overrides any previous text automatically added to the latex document by this
# function (i.e. to update the generated text).

import os # used to change directory and get path names
from re import match

# Edit the following line according to the name of the tool.
tool_name = "ReachCoreach"

# Find information related to the tool
def find_tool_info(tool_name):
    # Input:
    #       tool_name - string, e.g. "ReachCoreach", "AutoLayout"
    # Output: Dict with following keys:
    #       tex_name - string, name of latex file
    #       src_dir - string, path to the tool's source folder
    # e.g. tool_info = find_tool_info(tool_name)
    #      tex_name = tool_info["tex_name"]
    
    # Name of latex file for the SDD of the tool.
    # Currently this script must be saved in the same folder as this
    # latex file.
    tex_name = tool_name + "_sdd" + ".tex"
    
    # Path to the tool's source folder from
    # https://www.mcscert.ca/leap/svn/trunk/sw/tools/Simulink/
    src_dir = os.path.join("Tools", tool_name, "src")
    
    return {'tex_name': tex_name, 'src_dir': src_dir}

# Determine if given string is in given list of strings.
# If so, return the index of where to find it in the list.
def find_str_in_list(s,strlist):
    for i in range(0,len(strlist)):
        if(s == strlist[i]): #string in list
            return i #return index to find it
    return -1 #did not find a matching string name

# Given lines of MATLAB code, finds the first complete statement. When a
# line contains "...", the statement will end before that and continue on
# the next line (this ignores cases where "..." is used in char arrays).
def find_whole_matlab_stmt(lines):
    # Input:
    #       lines - list of strings representing lines of MATLAB
    # Output: Dict with following keys:
    #       stmt - whole MATLAB statement starting at lines[0]
    #       end_idx - index in lines where the statement ends
    # e.g. stmt_info = find_whole_matlab_stmt(lines)
    #      stmt = stmt_info["stmt"]
    line = lines[0]
    matchObj = match('(.*)\.\.\.(.*)', line)
    if matchObj == None:
        return {'stmt': line, 'end_idx': 0}
    else:
        assert len(lines)>1, 'lines ends before completing the MATLAB statement.'
        # Combine the first 2 lines and recurse
        lines[1] = matchObj.group(1) + ' ' + lines[1]
        lines.pop(0)
        stmt_info = find_whole_matlab_stmt(lines)
        stmt_info['end_idx'] += 1
        return stmt_info

def find_functions_and_classes_in_file(file):
    # Input:
    #       file - open text file
    # Output: Dict with following keys:
    #       names - list of function/class names found in file
    #       indexes_first - index of first line of the declaration
    #       indexes_last - index of last line of the declaration

    lines = file.readlines()
    
    names = []
    indexes_first = []
    indexes_last = []
    
    i = 0
    while i<len(lines):
        ln = lines[i]
        matchFunction = match('\s*(function)(\s+|\.\.\.)(.*)', ln)
        matchClass = match('\s*(classdef)(\s+|\.\.\.)(.*)', ln)
        if (matchFunction != None) or (matchClass != None):
            # Line declares a function or a class
            
            indexes_first.append(i) # first line of the declaration
            
            # Find the whole declaration
            stmt_info = find_whole_matlab_stmt(lines[i:])
            declaration = stmt_info['stmt']

            # Find the function/class name
            if matchFunction != None:
                # A function declaration looks like:
                # "function ___=___(___)",
                # where "___=" and "(___)" are optional
                names.append(match('\s*function\s+(.*=)?\s*(\w+)', declaration).group(2))
            elif matchClass != None:
                # A class declaration looks like:
                # "classdef (___)___<___&___
                # where "(___)" and "<___&___" are optional
                names.append(match('\s*classdef\s+(\(.*\))?\s*(\w+)', declaration).group(2))

            # Advance line index past the declaration
            i += stmt_info['end_idx']
            indexes_last.append(i) # last line of the declaration
            i += 1
            
        else:
            # Advance line index
            i += 1
    return {'names': names, 'indexes_first': indexes_first, 'indexes_last': indexes_last}
    
def find_functions_and_classes_in_dir(dir="."):
    # Find all functions and classes within the given directory. 
    # Return a list with an element for each .m file found at any depth from 
    # the src directory. Each element is a dict with the following -keys:
    #   'path' - string, path to the file
    #   'file' - string, name of the file (without extension)
    #   'names' - list of strings, function and class names declared in the 
    #             file
    #   'lines_first' - list of integers, indexes of first lines of the 
    #                   function/class declarations
    #   'lines_last' - list of integers, indexes of last lines of the 
    #                  function/class declarations (i.e. same as the first line
    #                  unless the declaration is continued on multiple lines 
    #                  using '...')
    func_class_info = []
    
    # For each directory found at the current directory (starting with the
    # current directory and proceeding recursively):
    for root, dirs, files in os.walk(dir):
        # For each file
        for filename in files:
            # Look for only matlab scripts by checking the extension of
            # the file
            if(filename.endswith(".m")): # File is a matlab script
                # Get the file path
                pathname = os.path.join(root,filename)

                with open(pathname, "r") as file:
                    func_class_names_and_lines = find_functions_and_classes_in_file(file)
                # Construct the dict for the current file
                # For path, ignore the leading ".\"
                # For file, ignore the extension
                func_class_info.append({'path': pathname[2:], \
                                        'file': filename[0:-2], \
                                        'names': func_class_names_and_lines['names'], \
                                        'lines_first': func_class_names_and_lines['indexes_first'], \
                                        'lines_last': func_class_names_and_lines['indexes_last']})
    return func_class_info

def update_latex(f_tex, func_class_info):
    # Contruct a list of lines to include in the latex document and then 
    # overwrite the document with those lines. Iterate through the original 
    # lines in the document and include them in the updated document unless 
    # they previously generated by this script (i.e. text between and including
    # "% >> Start auto gen <<" and "% >> End auto gen <<"). While iterating 
    # through the current document, if a subsection title corresponds with a 
    # function/class name used by the tool, include that function/class's 
    # prototype and description in an lstlisting and mark the start and end 
    # points of the generated text.
    
    # Create a list of lines to write into the latex document.
    new_latex = []
    # Variable is used to determine if a line being read from the latex
    # document should not be added to the list of lines to write into the latex
    # document.
    skipLines = False
    
    # Read all lines in the document and store it in a list.
    lines_sdd = f_tex.readlines()
    
    
    auto_gen_start = "% >> Start auto gen <<"
    auto_gen_end = "% >> End auto gen <<"
    prevLine_latex = "" # temp default value
    for currLine_latex in lines_sdd:
        # Set skipLines to skip previously auto generated lines
        if currLine_latex.startswith(auto_gen_start):
            skipLines = True
        elif prevLine_latex.startswith(auto_gen_end):
            skipLines = False
        
        if not skipLines:
            # Record that the current line should be in the updated
            # latex file.
            new_latex.append(currLine_latex)
            
            # Check if current line indicates the need for a function
            # description and prototype. All matlab function sections
            # are expected to be in a subsection, or a subsubsection.
            # If the title of the sub/subsubsection corresponds with a
            # matlab function within the list of functions, then the
            # description and prototype are needed.
            matchSubsection = match(".*subsection{(.*)}", currLine_latex)
            if matchSubsection != None:
                # Get the sub/subsection title i.e. the text within the 
                # curly brackets.
                fnc_name = matchSubsection.group(1)
                
                # Functions with "_" in the string are written with 
                # "\_" in latex, so get rid of the backslash.
                fnc_name = fnc_name.replace("\\_","_")
                
                # Check if the subsection title corresponds to a MATLAB 
                # function or class. If it does, include the prototype 
                # and description in latex for the first function or 
                # class found with the same name as the title.
                for i in range(0,len(func_class_info)):
                    j = find_str_in_list(fnc_name, func_class_info[i]["names"])
                    if j != -1:
                        # Subsection corresponds to a MATLAB function 
                        # or class.
                        
                        # Mark start of auto generated section in latex
                        new_latex.append(auto_gen_start + '\n')
                        # Insert the lstlisting starting point
                        new_latex.append("\\begin{lstlisting}\n")
                        
                        # Open the MATLAB script for reading and read  
                        # all lines
                        with open(func_class_info[i]["path"],"r") as f:
                            lines = f.readlines()
                            
                            # Add first to last line of the declaration
                            first_line = func_class_info[i]["lines_first"][j]
                            last_line = func_class_info[i]["lines_last"][j]
                            new_latex += lines[first_line:last_line+1]
                            
                            # Add lines until first uncommented line 
                            # (to include the whole function/class 
                            # description)
                            k = last_line+1
                            currLine = lines[k]
                            while(currLine.lstrip().startswith("%")):
                                new_latex.append(currLine)
                                k += 1
                                currLine = lines[k]
                        
                        # Insert the lstlisting ending point
                        new_latex.append("\\end{lstlisting}\n")
                        # Mark end of auto generated section in latex
                        new_latex.append(auto_gen_end + '\n')
                            
                        # Stop searching for a function with this name
                        break
        
        # Update previous line for next iteration.
        prevLine_latex = currLine_latex
    
    # Set the file pointer to the beginning of the file
    f_tex.seek(0,0)
    # Write all lines
    f_tex.writelines(new_latex)

init_dir = os.getcwd()

tool_info = find_tool_info(tool_name)
tex_name = tool_info["tex_name"]
src_dir = tool_info["src_dir"]

# Set directory to src code and find all functions/classes used in the tool.
os.chdir("..\..\..\..")
os.chdir(src_dir)
func_class_info = find_functions_and_classes_in_dir()

# Write function/class prototype and description information into the latex 
# document for subsections named the same as a function
tex_fullpath = os.path.join(init_dir, tex_name)
with open(tex_fullpath,"r+") as f_tex: # Open for reading and writing.
    update_latex(f_tex, func_class_info)