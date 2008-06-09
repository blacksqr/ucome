# And now all procedures for directories
# 05/31/2004 - protecting dfl_content for # and other in display_file_lol
lappend filetype_list dir

namespace eval dir {

	global DEBUG_PROCEDURES
	eval $DEBUG_PROCEDURES

	global STANDARD_PROCEDURES
	eval $STANDARD_PROCEDURES

	set level 0
	set index_file ""

	# Till now, display was handling the display of a file index. It 
	# was messy, as I change the name of file displayed. When asking
	# for edit, it was then editing the index file and not the
	# directory, which is bad. 
	# I try the following thing :
	# If it is a list, I send back a comp. However, it may be a 
	# file, either an index.xxx file or one in fas_env(dir.file_index)
	# In this case, I send back the filetype of this file, and
	# it will be taken, and sent back instead of the directory.
	# Warning, it will not work for a comp (to be seen).
	proc new_type { current_env filename } {
		upvar $current_env fas_env
		fas_debug "dir::new_type entering"
		#fas_debug_parray fas_env "dir::new_type - fas_env"
		# When a dir is met, in what filetype will it be by default
		# translated ?
		# set conf(newtype.dir) tmpl

		set result tmpl
		set INDEX_FILE_FLAG 0
		variable index_file
		# There is a special case, I may want to see a comp file
		# to show automatically the content of a directory
		# So is there a comp file ?
		if { [info exists fas_env(view.comp)] } {
			# So I want a comp as output
			set result comp
			fas_debug "dir::new_type - result is comp"
		}

		if { ![catch {set action [fas_get_value action] } ] } {
			if { $action != "view" } {
				# there is an action. Is it done or not
				fas_debug "dir::new_type - action is $action"
				fas_debug "dir::new_type ${action}::done is [set ${action}::done]"
				if { [set ${action}::done ] == 0 } {
					fas_debug "dir::new_type - action -> $action , action::done -> [set ${action}::done]"
					# the action was not processed
					set result $action
					return $result
				} ; # else I continue
			}
		} else {
			fas_debug "dir::new_type - not an action - viewing only"
		}

		# In nothing for a dir (just look at display hereunder
		# to understand)
		fas_debug "dir::new_type - second phase to find how to display the dir -> $result"
		if { [info exists fas_env(view.comp)] } {
			# So I want a comp as output
			set result comp
			fas_debug "dir::new_type - result is comp"
		} else {
			fas_debug "dir::new_type - not a comp"
			# I am going to try the following thing
			# If there is an index file, I display it
			# else I display an edit_form with some basic display_list
			if { [info exists fas_env(dir.file_index)] } {
				fas_debug "dir::new_type - found fas_env(dir.file_index)"
				set file [file join $filename $fas_env(dir.file_index)]
				# Does this file exists ?
				if { [file readable $file] } {
					# OK there is a fas_env(dir.file_index) I use it
					fas_debug "dir::new_type - using $file as index"
					set INDEX_FILE_FLAG 1
					set index_file $file
				} else {
					global _cgi_uservar
					if { ![info exists _cgi_uservar(display)] } {
						set _cgi_uservar(display) "shortname,title"
						set _cgi_uservar(noadd) 1
					} 
					fas_debug "dir::new_type - displaying an edit_form"
					set result comp
					#set result edit_form
				}
			} else {
				fas_debug "dir::new_type - testing list of files"
				set potential_list [glob -nocomplain [file join $filename "index.*"]]
				if { [llength $potential_list] > 0 } {
					# I take the first file of index.* files
					fas_debug "dir::new_type - error - using index.*"
					set INDEX_FILE_FLAG 1
					set index_file [lindex $potential_list 0]
				} else {
					# But in a very minimal way
					global _cgi_uservar
					if { ![info exists _cgi_uservar(display)] } {
						set _cgi_uservar(display) "shortname,title"
						set _cgi_uservar(noadd) 1
					} 
					fas_debug "dir::new_type - displaying an edit_form"
					set result comp
					if { [info exists _cgi_uservar(target)] } {
						# we are in the standard case nothing to do
						switch -exact -- $_cgi_uservar(target) {
							nomenu {
								set result fashtml
							}
						}
					}
				}
			}
		}
		# Are we in the INDEX_FILE_FLAG case ?
		if $INDEX_FILE_FLAG {
			# I get the filetype of the index_file
			read_full_env $index_file file_env
			global conf
			set result [guess_filetype $index_file conf file_env]
			main_log "dir::2new_type - using [rm_root $index_file]"
			fas_debug "dir::2new_type - using $index_file"
		}
		fas_debug "dir::new_type - returning $result"
		return $result
	}
	
	proc init { } {
		variable index_file
		set index_file ""
	}

	proc new_type_list { } {
		return [list tmpl fashtml]
	}

	# This procedure returns the list of important session variables for
	# this type of file
	proc important_session_keys { } {
		# not any one
		return [list]
	}

	# Return the list of environment variables that are important
	proc env { args } {
		set env_list ""
		lappend env_list [list "dir.file_index" "File to use when displaying a directory. The file must be in the directory, and given without path (only the filename such as foo.txt)." webmaster]
		lappend env_list [list "dir.linestoshow" "Nber of files to show while showing the directory content." user]
		lappend env_list [list "dir.template" "Html file with special tags for displaying the content of a directory." webmaster]
                # The next entry comes straight on from comp.tcl
                # But it is used when creating a new file. So it is called from a directory
                # and then is attached to the directories.
                lappend env_list [list "new.comp.form_list" "The list of template available for this file" webmaster]
                lappend env_list [list "dir.create_filetype_list" "The list of file type that can be created in a directory. * means any filetype." admin]
                return $env_list
	}

	proc may_create { } {
		return 1
	}

	# Procedure for creating a new directory :
	# First I create the directory, then I call edit on it, 
	# At the end I exit
	proc new { current_env current_conf dirname filename filetype ON_EXTENSION_FLAG } {
		fas_debug "dir::new - $dirname $filename $filetype $ON_EXTENSION_FLAG current_env current_conf"
		upvar $current_env fas_env
		upvar $current_conf fas_conf

		set new::done 1
		# What is the real file to create
		set full_filename [file join $dirname $filename]
		fas_debug "dir::new - creating directory $full_filename"

		# Trying to create it
		if [catch {file mkdir $full_filename} error] {
			# There was an error, I display it
			fas_display_error "[translate "Impossible to create "] $full_filename [translate " directory for writing"] - $error" fas_env -f $dirname
		} else {
			# And now the real high tech
			# I am going to jump to the edition page
			# on this empty file. So I need to cleanup
			global _cgi_uservar
			unset _cgi_uservar
			set _cgi_uservar(action) edit_form
			#global DEBUG
			#set _cgi_uservar(debug) $DEBUG

			display_file dir $full_filename fas_env fas_conf
			# And I exit as something will be displayed
			fas_exit
		}
	}

	proc 2tmpl { current_env args } {
		upvar $current_env env
		return "[eval 2fashtml env $args]"
	}
	
	proc 2treedir { current_env args } {
		upvar $current_env env
		return "[eval 2fashtml env $args]"
	}
	
	proc content2tmpl { current_env args } {
		upvar $current_env env
		return "[eval content2fashtml env $args]"
	}
	
	proc content2treedir { current_env args } {
		upvar $current_env env
		return "[eval content2fashtml env $args]"
	}

	proc 2comp { current_env args } {
		fas_debug "dir::2comp - $args"
		upvar $current_env env
		set tmp(content.content) "[extract_body [eval 2fashtml env $args ]]"
		return "[array get tmp]"
	}

	# This procedure will translate a directory into html 
	proc 2fashtml { current_env filename } {
		fas_debug "dir::2fashtml - current_env "
		upvar $current_env fas_env

		variable index_file
		if { $index_file == "" } {
			# normal case - creating the list
			# chunk_string is used when displaying list by chunks.
			# I put there all the elements usefull for creating the display url
			set chunk_string "action=view&"
			global conf

			# The directory is its own dependency
			fas_depend::set_dependency $filename file

			# Template name may come from the fas_env, then I take it
			fas_depend::set_dependency $filename fas_env

			# First I need some informations 
			# I do a distinction with the edit_form
			set display [fas_get_value view.display -default "filetype,shortname,title"]
			append chunk_string "view.display=${display}&"
			set order [fas_get_value view.order -default ""]
			append chunk_string "view.order=${order}&"
			set extension_list [fas_get_value view.extension_list -default "*"]
			append chunk_string "view.extension_list=${extension_list}&"
			set colnber [fas_get_value colnber -default 1]
			#append chunk_string "colnber=${colnber}&"
			#set noadd [fas_get_value noadd -default 1]
			# When looking at a file it is not possible to add a new one
			set noadd 1
			append chunk_string "noadd=${noadd}&"
			set reverse [fas_get_value view.reverse -default "0"]
			append chunk_string "view.reverse=${colnber}&"
			set linestoshow [fas_get_value dir.linestoshow -default -1]
			append chunk_string "linestoshow=${linestoshow}&"
			set chunk [fas_get_value chunk -default 0]
			
			# but not chunk
			
			set display_list [split $display ","]
			set file_lol [get_file_lol $filename fas_env -w $display_list -o $order -f $extension_list -r $reverse]

			set message [fas_get_value message -default ""]
			append chunk_string "message=${message}"
			set content [display_file_lol $file_lol fas_env -title "[translate Directory] [rm_root $filename]" -d $display_list -c $colnber -m $message -r [rm_root $filename] -l $linestoshow -h $chunk -s $chunk_string -n $noadd]
			return $content
		} else {
			fas_debug "dir::2fashtml - found an index_file using it - $index_file"
			# I display an html file as index
			if { [catch {
				set fid [open $index_file]
				set content [read $fid]
				close $fid
			} ] } {
				return "[translate "Problem while loading"] [rm_root2 $index_file] [translate " while displaying directory"] [rm_root $filename]"
			}
			fas_depend::set_dependency $index_file file
			set index_file ""
			return $content
		}
	}

	proc content2fashtml { current_env content } {
		fas_display_error "[translate "Could not display string as a dir."]" env
	}
	
	foreach type [list txt code sxw sxc sxi csv gif jpeg mpeg png tiffg3 sxd pdf tmpl xml avi mp4] {
		proc 2${type} { current_env filename } {
			fas_debug "dir::2xxx - current_env - entering"
			upvar $current_env fas_env

			# If I am here it means that a txt index file was found.
			# I just need to take it, and send it back
			variable index_file
			if { $index_file == "" } {
				return "[translate "No index file for current directory"] [rm_root2 $filename]"
			} else {
				if { [catch {
					set fid [open $index_file]
					set content [read $fid]
					close $fid
					# I should also load all env variables
					read_full_env $index_file fas_env
				} ] } {
					return "[translate "Problem while loading"] [rm_root $index_file] [translate " while displaying directory"] [rm_root $filename]"
				}
			}
			fas_depend::set_dependency $index_file file
			set index_file ""
			return $content
		}
	}

	proc get_title { dirname } {
		return "[translate "Directory"]"
	}

	# NAME : get_file_lol
	# Function : send back the list of files corresponding to filter (default *)
	# The file is ALWAYS sent back at the start of the list. You do
	# not need to mention it.
	# Arguments :
	#	-what what_list : a list of elements to send back. Possible values 
	#                         are file, shortname, extension, filetype, dir, title, size, mtime, allow
	#	-order order : element on which to sort the result (default file)
	#	-n[umorder] : element on which to order is treated as a numerical value
	#	-filter filter : expression to use for knowing what to display
	#			 it should be a single element as *.tar or
	#                        *.tgz or *.tbz 
	#	-dir : send the directores in this directory and not the file
	#	-comp_only : only comp files with a given form name
	#			will be displayed
	#       -r[everse] : reverse order for display
	# The result is a list of list (lol) the first element of which
	# is the list of elements in each sublist.
	proc get_file_lol { dir current_env args } {
		fas_debug "dir::get_file_lol - $dir - $args"
		global conf
		upvar $current_env fas_env
		set state menu_args
		set order "file"
		set filter "*"
		set what_list "file"
		set COMP_ONLY_FLAG 0
		set REVERSE_FLAG 0
		set NUMORDER_FLAG 0
		# I need a default value for desired_form
		set desired_form ""
		foreach arg $args {
			switch -exact -- $state {
				menu_args {
					switch -glob -- $arg {
						-w* {
							set state what
						}
						-o* {
							set state order
						}
						-f* {
							set state filter
						}
						-c* {
							set state comp_only
						}
						-r* {
							set state reverse
						}
						-n* {
							set state numorder
						}
						default {
							# nothing to do
						}
					}
				}
				what {
					set what_list $arg
					set state menu_args
				}
				order {
					set order $arg
					set state menu_args
				}
				filter {
					set filter $arg
					set state menu_args
				}
				comp_only {
					if { $arg != "" } {
						set COMP_ONLY_FLAG 1
						set desired_form $arg
					}
					set state menu_args
				}
				reverse {
					set REVERSE_FLAG $arg
					set state menu_args
				}
				numorder {
					set NUMORDER_FLAG $arg
					set state menu_args
				}
			}
		}
		fas_debug "dir::get_file_lol - desired_form -> $desired_form , COMP_ONLY_FLAG -> $COMP_ONLY_FLAG, what_list -> $what_list"
		# first getting the file list
		set file_list ""
		foreach filt [split $filter ","] {
			set current_filter_string "[file join $dir $filt]"
			eval lappend file_list [glob -type {f d} -nocomplain $current_filter_string]
		}
		
		#set filter_string "[file join $dir $filter]"
		#fas_debug "$filter_string"
		#set file_list [glob -type {f d} -nocomplain $filter_string]
		
		#fas_debug "set file_list \[glob -type f -nocomplain $filter_string\]"
		#fas_debug "set file_list [glob -type f -nocomplain $filter_string]"
		fas_debug  "dir::get_file_lol file_list -> $file_list" 
		set final_file_list ""
		set what_list [linsert $what_list 0 "file"]
		#fas_debug  "dir::get_file_lol what_list -> $what_list" 
		foreach file $file_list {
			set current_file_list ""
			catch { unset file_env }
			catch { unset menu_env }
			catch { unset current_filetype }
			catch { unset current_comp }
			# This flag will allow to take only composite file
			# of a certain type
			set COMP_FLAG 0
			foreach element $what_list {
				switch -glob -- $element {
					file {
						# This file is only used after
						# for creating url => I suppress
						# the root from it
						lappend current_file_list [rm_root $file]
					}
					shortname {
						set extension [file extension $file]
						regsub "$extension\$" [file tail $file] {} shortname
						lappend current_file_list $shortname
					}
					extension {
						set extension [string trim [file extension $file]]
						if { $extension == "" } {
							set extension "&nbsp;"
						}
						lappend current_file_list $extension
					}
					filetype {
						catch { unset file_env }
						read_full_env $file file_env
						set current_filetype [guess_filetype $file conf file_env]
						lappend current_file_list $current_filetype
					}
					dir {
						set dir [file dirname $file]
						lappend current_file_list $dir
					}
					title { 
						# OK I must get the title of this file type
						# WARNING !!! I need to read the corresponding env
						catch { unset file_env }
						read_full_env $file file_env
						set filetype [guess_filetype $file conf file_env]
						if { [info exists file_env(title.title)] } {
							set title $file_env(title.title)
						} else {
							set title [${filetype}::get_title $file ]
						}
						# Avoid blank array space
						if { $title == "" } { set title "&nbsp;" }
						lappend current_file_list $title
					}
					fax_name { 
						catch { unset file_env }
						read_full_env $file file_env
						set filetype [guess_filetype $file conf file_env]
						set fax_name [${filetype}::2nice_fax_name file_env $file ]
						# Avoid blank array space
						if { $fax_name == "" } { set fax_name "&nbsp;" }
						lappend current_file_list $fax_name
					}
					first_fax_page {
						# I need shortname, but I am not sure that
						# it was asked for creating the first page name
						# I work it out again. Pure copy
						set extension [file extension $file]
						regsub "$extension\$" [file tail $file] {} first_fax_page
						lappend current_file_list $first_fax_page
					}
					size {
						lappend current_file_list [file size $file]
					}
					mtime {
						lappend current_file_list [file mtime $file]
					}
					comp_elt.* {
						# Here I try to be able to take values from comp files.
						# It will work only for comp file of a given type (having a given template)
						# Or having a given filetype
						# Needed values are : desired_form  or desired_type
						# Desired type will be implemented
						# later. First desired_form
						set desired_type [fas_get_value dir.comp.desired_type -default ""]
						if { [regexp {comp_elt\.(.*)$} $element match elt_name] } {
							fas_debug "dir::get_file_lol - comp_elt - elt_name => $elt_name"
							if { ![info exists file_env] } {
								read_full_env $file file_env
								set current_filetype [guess_filetype $file conf file_env]
							}
							fas_debug "dir::get_file_lol - comp_elt current_filetype => $current_filetype"
							if { ( ${current_filetype} == "comp" ) || ( ${current_filetype} == ${desired_type} ) } {
								fas_debug "dir::get_file_lol - comp_elt - found comp"
								if { ![info exists current_comp] } {
									read_env $file current_comp
									#fas_debug_parray current_comp "dir::get_file_lol - comp_elt -> current_comp"
								}
								if { [info exists current_comp(####)] } {
									fas_debug "dir::get_file_lol -> testing comp type - $current_comp(####) =? $desired_form"
									# VEON version - with ~ ???
									#if { $current_comp(####) ==~ $desired_form } 
									if { $current_comp(####) == $desired_form } {
										fas_debug "dir::get_file_lol -> YES"
										set COMP_FLAG 1
									}
								} 
								if { $current_filetype == $desired_type } {
									set COMP_FLAG 1
								}
								if { [info exists current_comp($elt_name)] } {
									lappend current_file_list $current_comp($elt_name)
									fas_debug "dir::get_file_lol - comp_elt found $elt_name in current_comp"
								} else {
									lappend current_file_list "&nbsp;"
									fas_debug "dir::get_file_lol - comp_elt NOT found $elt_name in current_comp"
								}
							} else {
								lappend current_file_list ""
							}
						} else {
							lappend current_file_list ""
						}
					}	
					fasenv.* {
						# Here I try to be able to take values from the env. variables of the file
						# If the value does not exists, I put ""
						if { [regexp {fasenv\.(.*)$} $element match elt_name] } {
							#fas_debug "dir::get_file_lol - fasenv - elt_name => $elt_name"
							if { ![info exists menu_env] } {
								read_dir_env $file menu_env
							}
							if { [info exists menu_env($elt_name)] } {
								lappend current_file_list $menu_env($elt_name)
								#fas_debug "dir::get_file_lol - comp_elt found $elt_name in current_comp"
							} else {
								lappend current_file_list ""
								#fas_debug "dir::get_file_lol - comp_elt NOT found $elt_name in current_comp"
							}
						} else {
							lappend current_file_list ""
						}
					}
					Candidate_order -
					Copy -
					Edit -
					Delete -
					Properties -
					Allow -
					default {
						# I put an empty value to keep
						# the number of elements in the list
						# equal to the input
						 lappend current_file_list ""
					}
				}
			}
			#fas_debug "current_file_list : $current_file_list"
			if { $COMP_ONLY_FLAG } {
				if { $COMP_FLAG } {
					lappend final_file_list $current_file_list
				}
			} else {
				lappend final_file_list $current_file_list
			}
		}
		set order_element [lsearch -exact $what_list $order]
		if { $order_element >= 0 } {
			if $REVERSE_FLAG {
				if $NUMORDER_FLAG {
					set file_list [lsort -integer -decreasing -index $order_element $final_file_list]
				} else {
					set file_list [lsort -decreasing -index $order_element $final_file_list]
				}
			} else {
				if $NUMORDER_FLAG {
					set file_list [lsort -integer -index $order_element $final_file_list]
				} else {
					set file_list [lsort -index $order_element $final_file_list]
				}
			}
		} else {
			if $REVERSE_FLAG {
				set file_list [lsort -decreasing -index 0 $final_file_list]
			} else {
				set file_list [lsort -index 0 $final_file_list]
			}
		}
		set file_list [linsert $file_list 0 $what_list]
		fas_debug "dir::get_file_lol : result => $file_list"
		return $file_list
	}

	# Prepare the template to display a file in a single row
	proc display_row { dfl_name_list dfl_display_list file_list args } {
		set state menu_args
		set COUNTER_FLAG 0
		foreach arg $args {
			switch -exact -- $state {
				menu_args {
					switch -glob -- $arg {
						-c* {
							set state count
						}
						default {
						}
					}
				}
				count {
					set COUNTER_FLAG 1
					set counter $arg
					set state menu_arg
				}
			}
		}

		# I handle common variables for this template
		global FAS_VIEW_CGI
		set icons_url [fas_name_and_dir::get_icons_dir]
		#set icons_url [fas_get_value icons_url -default "fas:/icons"]	

		# I am going to prepare the local variables
		# with the different content. By default
		# I will add content as being the current element
		# For Copy Delete Properties and Edit value will
		# be ""
		foreach dfl_name $dfl_name_list dfl_content $file_list {
			# I put in the corresponding variables
			# the values. I suppose that the
			# values are not starting with dfl
			set $dfl_name $dfl_content
			# If you want a debug for display_row it is the next one
			# which is the good one.
			#fas_debug "dir::display_row $dfl_name -> $dfl_content"
		}
		# So the possible values are :
		# => file, shortname, filetype, extension, dir, title, size
		# mtime, start_time, end_time, rolling_speed, order_name, uri
		# No other values are available. So they must
		# be used. I just have to use these variables
		# in the template and then to do the substitution
		set atemt::_atemt(FILE_ROW) $atemt::_atemt(FILE_LIST)
		if { [expr $counter % 2] == 1 } {
			if { [info exists atemt::_atemt(FILE_LIST_ODD)] } {
				set atemt::_atemt(FILE_ROW) $atemt::_atemt(FILE_LIST_ODD)
			}
		}

		foreach dfl_display_element $dfl_display_list {
			if { [info exists atemt::_atemt([string toupper $dfl_display_element])] } {
				set atemt::_atemt(FILE_CELL) $atemt::_atemt([string toupper $dfl_display_element])
				# fas_debug "dir::display_row - found _atemt([string toupper $dfl_display_element])"
			} else {
				# I display nothing
				# fas_debug "display_lol - could not find _atemt([string toupper $dfl_display_element])"
			}
			#set atemt::_atemt(FILE_ROW) [atemt::atemt_subst -insert -block FILE_CELL FILE_ROW]
			atemt::atemt_set FILE_ROW -bl [atemt::atemt_subst_insert FILE_CELL FILE_ROW]
		}
		# fas_debug "display_file_lol -  substituing FILE_ROW in DIRECTORY_CONTENT => $atemt::_atemt(FILE_ROW) , $atemt::_atemt(DIRECTORY_CONTENT)"
		#set atemt::_atemt(ALL_FILE_ROWS) [atemt::atemt_subst -insert -block FILE_ROW ALL_FILE_ROWS]
		atemt::atemt_set ALL_FILE_ROWS -bl [atemt::atemt_subst_insert FILE_ROW ALL_FILE_ROWS]
	}

	# List of filetype for which it is possible to create a new file in
	# editing an empty file.
	proc create_filetype_list { current_env} {
		upvar $current_env fas_env
		global filetype_list 
		
		set result_list ""
		set current_filetype_list $filetype_list
		if { [info exists fas_env(dir.create_filetype_list)] } {
			if { $fas_env(dir.create_filetype_list) != "*" } {
				set current_filetype_list $fas_env(dir.create_filetype_list)
			}
		}
		fas_debug "dir::create_filetype_list filetype_list -> $filetype_list"
		foreach filetype $current_filetype_list {
			# fas_debug "dir::create_filetype_list $filetype -> [info commands ${filetype}::may_create]"
			if { ![catch { ${filetype}::may_create }] } {
				lappend result_list $filetype
			}
		}
		if { ![info exists fas_env(dir.create_filetype_list)] } {
			set result_list [linsert $result_list 0 [translate "On extension"]]
		} elseif {  $fas_env(dir.create_filetype_list) == "*" } {
			set result_list [linsert $result_list 0 [translate "On extension"]]
		}
		return $result_list
	}
		
	# Display of file_lol on an html table
	# Arguments :
	#  * file_lol : a lol with first element giving the elements of the rest
	#    of the list.
	# * -title "A title" : title of the page (default "")
	# * -colnber -cn X : nber of columns to use for the display (default file)
	# * -linestoshow -l X : number of lines to show
	# * -hunk -h X : chunk of lines to show depending of linestoshow number.
	# * -display_list {list of elements to display} : the list of element to
	#     display (file, shortname, extension, title, mtime, size, Delete, Copy, Edit, Properties)
	# * -i table_id  => <table border="0" id="$table_id">
	proc display_file_lol { dfl_file_lol current_env args } {
		upvar $current_env fas_env 
		fas_debug "dir::display_file_lol - $dfl_file_lol - $args"
		global FAS_VIEW_CGI
		global FAS_UPLOAD_CGI

		set state menu_args
		set dfl_dirname ""
		set dfl_colnber "1"
		set dfl_display_list "file"
		set title ""
		set tableid ""
		set dfl_form_flag 0
		set dfl_noadd_flag 0
		set lines_to_show -1
		set chunk 0
		set chunk_string ""
		set CHUNK_SECTION_FLAG 0
		set message ""
		foreach arg $args {
			switch -exact -- $state {
				menu_args {
					switch -glob -- $arg {
						-r* {
							set state dirname
						}
						-c* {
							set state colnber
						}
						-d* {
							set state display_list
						}
						-t* {
							set state title
						}
						-m* {
							set state message
						}
						-f* {
							set state form
						}
						-n* {
							set state noadd
						}
						-l* {
							set state linestoshow
						}
						-h* {
							set state chunk
						}
						-s* {
							set state chunk_string
						}
						-i* {
							set state tableid
						}
						default {
							# nothing to do
						}
					}
				}
				dirname {
					set dfl_dirname $arg
					set dir $dfl_dirname
					fas_debug "dir::display_file_lol dir is $dir"
					set state menu_args
				}
				colnber {
					set dfl_colnber $arg
					fas_debug "dir::display_file_lol - dfl_colnber =>${dfl_colnber}"
					set state menu_args
				}
				display_list {
					set dfl_display_list $arg
					set state menu_args
				}
				title {
					set title $arg
					set state menu_args
				}
				tableid {
					set tableid "id=\"$arg\""
					set state menu_args
				}
				message {
					set message $arg
					set state menu_args
				}
				form {
					set dfl_form_flag $arg
					fas_debug "dir::display_file_lol - dfl_form_flag =>${dfl_form_flag}"
					set state menu_args
				}
				noadd {
					set dfl_noadd_flag $arg
					fas_debug "dir::display_file_lol - dfl_noadd_flag =>${dfl_noadd_flag}"
					set state menu_args
				}
				linestoshow {
					set lines_to_show $arg
					set state menu_args
				}
				chunk {
					set chunk $arg
					set state menu_args
				}
				chunk_string {
					set chunk_string $arg
					set state menu_args
				}
			}
		}

		# First I load the template
		set dfl_template_name [fas_name_and_dir::get_template_name fas_env "dir.template"]
		atemt::read_file_template_or_cache "DIRECTORY_CONTENT" "$dfl_template_name" 
		fas_depend::set_dependency $dfl_template_name file
		
		# Getting the default icons_url path
		set icons_url [fas_name_and_dir::get_icons_dir]

		# I first need to handle the CREATE_FORM at the beginning of the template
		set create_filetype_list [create_filetype_list fas_env]
		fas_debug "dir::display_file_lol - create_filetype_list ->$create_filetype_list"
		global DEBUG
		# Now adding the options in the select
		if { !$dfl_noadd_flag } {
			foreach filetype $create_filetype_list {
				set option $filetype
				#set atemt::_atemt(CREATE_FORM) [atemt::atemt_subst -insert -block FILETYPE_OPTION CREATE_FORM]
				atemt::atemt_set CREATE_FORM -bl [atemt::atemt_subst_insert FILETYPE_OPTION CREATE_FORM]
				fas_debug "dir::display_file_lol - adding --  $filetype -- to creatable types"
			}
		}
	
		# I handle common variables for this template

		# now I set the title
		atemt::atemt_set HEAD_TITLE $title
		atemt::atemt_set TOP_TITLE $title
		atemt::atemt_set MESSAGE $message
		atemt::atemt_set TABLEID $tableid

		# If I have a colnber, I can now get a colheight 
		# which is the number of rows in a column
		fas_debug "dir::display_file_lol --- dfl_file_lol -> $dfl_file_lol --- llength dfl_file_lol -> [llength $dfl_file_lol] --- dfl_colnber -> $dfl_colnber"
		fas_debug "dir::display_file_lol -- dfl_display_list => $dfl_display_list"
		# WARNING
		# BUG if we are in colnber > 1 and linestoshow != -1 => the algo does not work
		set dfl_colheight [expr ( [llength $dfl_file_lol] - 1 ) / $dfl_colnber]
		if { $dfl_colheight == 0 } { set dfl_colheight 1 }
		set what_list [lindex $dfl_file_lol 0]

		# if there is only a certain nber of elements to show	
		# I take it into account
		if { $lines_to_show != "-1" } {
			set CHUNK_SECTION_FLAG 1
			set start_indice [expr $lines_to_show * $chunk ]
			set end_indice [expr $start_indice + $lines_to_show - 1 ]
			set all_lines_nber [expr [llength $dfl_file_lol] -1]
			if { $end_indice > $all_lines_nber } {
				set $end_indice end
			}
		} else {
			set start_indice 0
			set end_indice end
		}
		foreach dfl_display_element $dfl_display_list {
			if { [info exists atemt::_atemt([string toupper $dfl_display_element]_HEADER)] } {
				set atemt::_atemt(HEADER_CELL) $atemt::_atemt([string toupper $dfl_display_element]_HEADER)
				#fas_debug "display_lol - found _atemt([string toupper $dfl_display_element]_HEADER)"
			} else {
				# I use the default value
				set content "$dfl_display_element"
				set atemt::_atemt(HEADER_CELL) $atemt::_atemt(DEFAULT_HEADER)
				#fas_debug "display_lol - found _atemt(DEFAULT_HEADER)"
			}
			#set atemt::_atemt(FILE_TABLE_HEADER) [atemt::atemt_subst -insert -block HEADER_CELL FILE_TABLE_HEADER]
			atemt::atemt_set FILE_TABLE_HEADER -bl [atemt::atemt_subst_insert HEADER_CELL FILE_TABLE_HEADER]
		}
		# What I must do is construct the content line after line
		# from a template and then put all templates on the same page
		set dfl_name_list [fast_fetch_name $dfl_file_lol]
		set counter 0
		foreach file_list [lrange [fast_fetch_data $dfl_file_lol] $start_indice $end_indice] {
			# I am going to prepare the local variables
			# with the different content. By default
			# I will add content as being the current element
			# For Copy Delete Properties and Edit value will
			# be ""

			# I have a performance problem here. It is too slow as a function
			# Then I inline the function and optimize it.
			#display_row $dfl_name_list $dfl_display_list $file_list -c $counter

		# I am going to prepare the local variables
		# with the different content. By default
		# I will add content as being the current element
		# For Copy Delete Properties and Edit value will
		# be ""
		foreach dfl_name $dfl_name_list dfl_content $file_list {
			# I think that I need to protect special variables for url
			# I try - AL 31/05/2004
			if { $dfl_name == "file" } {
				regsub -all {%}  $dfl_content "%25" dfl_content
				regsub -all {&}  $dfl_content "%26" dfl_content 
				regsub -all {\+} $dfl_content "%2b" dfl_content
				regsub -all { }  $dfl_content "+"   dfl_content
				regsub -all {=}  $dfl_content "%3d" dfl_content
				regsub -all {#}  $dfl_content "%23" dfl_content
				#regsub -all {/}  $dfl_content "%2f" dfl_content
			}
			# I put in the corresponding variables
			# the values. I suppose that the
			# values are not starting with dfl

			set $dfl_name $dfl_content
			# If you want a debug for display_row it is the next one
			# which is the good one.
			fas_debug "dir::display_row $dfl_name -> $dfl_content"
		}
		# So the possible values are :
		# => file, shortname, filetype, extension, dir, title, size
		# mtime, start_time, end_time, rolling_speed, order_name, uri, ...
		# No other values are available. So they must
		# be used. I just have to use these variables
		# in the template and then to do the substitution
		set atemt::_atemt(FILE_ROW) $atemt::_atemt(FILE_LIST)
		if { [expr $counter % 2] == 1 } {
			if { [info exists atemt::_atemt(FILE_LIST_ODD)] } {
				set atemt::_atemt(FILE_ROW) $atemt::_atemt(FILE_LIST_ODD)
			}
		}

		foreach dfl_display_element $dfl_display_list {
			if { [info exists atemt::_atemt([string toupper $dfl_display_element])] } {
				set atemt::_atemt(FILE_CELL) $atemt::_atemt([string toupper $dfl_display_element])
				# fas_debug "dir::display_row - found _atemt([string toupper $dfl_display_element])"
				#set atemt::_atemt(FILE_ROW) [atemt::atemt_subst -insert -block FILE_CELL FILE_ROW]
				atemt::atemt_set FILE_ROW -bl [atemt::atemt_subst_insert FILE_CELL FILE_ROW]
			} else {
				# I display nothing
				# fas_debug "display_lol - could not find _atemt([string toupper $dfl_display_element])"
			}
			#set atemt::_atemt(FILE_ROW) [atemt::atemt_subst -insert -block FILE_CELL FILE_ROW]
		}
		# fas_debug "display_file_lol -  substituing FILE_ROW in DIRECTORY_CONTENT => $atemt::_atemt(FILE_ROW) , $atemt::_atemt(DIRECTORY_CONTENT)"
		#set atemt::_atemt(ALL_FILE_ROWS) [atemt::atemt_subst -insert -block FILE_ROW ALL_FILE_ROWS]
		atemt::atemt_set ALL_FILE_ROWS -bl [atemt::atemt_subst_insert FILE_ROW ALL_FILE_ROWS]




			incr counter
		}
		# Now I must substitute and close everything
		set dir $dfl_dirname
		# Do I want the START_FORM and END_FORM (for having a form for select checkbox ?
		if { $dfl_form_flag } {
			set atemt::_atemt(DIRECTORY_CONTENT) [atemt::atemt_subst  -block START_FORM -block END_FORM DIRECTORY_CONTENT]

		}
		# Do I want the CREATE_FORM at start ? Default is I want it.
		if { !$dfl_noadd_flag } {
			set atemt::_atemt(DIRECTORY_CONTENT) [atemt::atemt_subst -block CREATE_FORM  DIRECTORY_CONTENT]
		}
		# Do I need a CHUNK_SECTION ?
		# What is the number of chunk ?
		# In what chunk are we ?
		# So in CHUNK_SECTION there are PREVIOUS, NEXT, CURRENT_CHUNK, NEXT_CHUNK
		if { $CHUNK_SECTION_FLAG } {
			# nber of chunk ?
			set current_action $chunk_string
			set chunk_nber [expr $all_lines_nber / $lines_to_show ]
			if { $chunk > 0 } {
				set i [expr $chunk - 1]
				atemt::atemt_set CHUNK_SECTION -bl [atemt::atemt_subst -block PREVIOUS CHUNK_SECTION]
			}
			set max_chunk_nber [expr $chunk_nber - 1]
			if { $chunk < $max_chunk_nber } {
				set i [expr $chunk + 1]
				atemt::atemt_set CHUNK_SECTION -bl [atemt::atemt_subst -block NEXT CHUNK_SECTION]
			}
			for { set i 0 } { $i < $chunk_nber } { incr i } {
				if { $i == $chunk } {
					atemt::atemt_set NEXT_CHUNK -bl [atemt::atemt_set CURRENT_CHUNK]
				} else {
					atemt::atemt_set NEXT_CHUNK -bl [atemt::atemt_set CHUNK]
				}
				#atemt::atemt_set CHUNK_SECTION -bl [atemt::atemt_subst -insert -block NEXT_CHUNK CHUNK_SECTION]
				atemt::atemt_set CHUNK_SECTION -bl [atemt::atemt_subst_insert NEXT_CHUNK CHUNK_SECTION]
			}
		}
			
		set atemt::_atemt(DIRECTORY_CONTENT) [atemt::atemt_subst -block FILE_TABLE_HEADER -block HEAD_TITLE -block TOP_TITLE -block ALL_FILE_ROWS -block MESSAGE -block CHUNK_SECTION -block TABLEID DIRECTORY_CONTENT]
			
		#set dfl_final_html [atemt::atemt_subst -end DIRECTORY_CONTENT]
		set dfl_final_html [atemt::atemt_subst_end DIRECTORY_CONTENT]
		#fas_debug "dir::display_file_lol -- showing array dir array"
		#fas_debug_parray atemt::_atemt
		#fas_debug "dir::display_file_lol --------------------------"
		#fas_debug "dir::display_file_lol - END RETURNING - $dfl_final_html"
		return $dfl_final_html 
	}

	# Retrieve only the data of the list with
	# a first list containing the name of the elements
	proc fast_fetch_data { lol } {
		return [lrange $lol 1 end]
	}

	# Retrieve only the name of the element in the structured
	# list. It is the first list with the name of the elements
	proc fast_fetch_name { lol } {
		return [lindex $lol 0]
	}

	proc fast_fetch_struct_lol { element_list fast_list } {
		set result_lol ""
		foreach fast_element $fast_list {
			set what_rank [ lsearch $element_list $fast_element ]
			if  { $what_rank > -1 } {
				lappend result_lol [list $fast_element $what_rank]
			} else {
				fas_debug "fast_fetch_struct_lol - Could not find $fast_element in $element_list"
			}
		}
		return $result_lol
	}


	# I THINK THAT THE NEXT FUNCTION IS DEPRECATED AND CAN BE DELETED
	# TODO REMOVE NEXT FUNCTION
	# If an element in fast_list is Copy Delete or Modify
	# I take it.
	#proc special_cde_fast_fetch_struct_lol { element_list fast_list } {
	#	set result_lol ""
	#	foreach fast_element $fast_list {
	#		set what_rank [ lsearch $element_list $fast_element ]
	#		if  { $what_rank > -1 } {
	#			lappend result_lol [list $fast_element $what_rank]
	#		} elseif { $fast_element == "Copy" || \
	#			$fast_element == "Delete" || \
	#			$fast_element == "Edit" || \
	#			$fas_element == "Allow" }  {
	#			set button_rank [lsearch $element_list "file"]
	#			# For buttons, I need the file element to create them
	#			lappend result_lol [list $fast_element $button_rank]
	#		} else {
	#			fas_debug "fast_fetch_struct_lol - Could not find $fast_element in $element_list"
	#		}
	#	}
	#	return $result_lol
	#}

	# Now all procedures for the actions
	# I will always ask for a new object from a directory
	# So then, I need to pick up the adapted function
	# depending on the filetype for the new object
	# But basically, I create a new object and I
	# call an edit function on it. Well it depends
	# on the filetype.
	proc 2new { current_env filename } {
		upvar $current_env fas_env
		fas_debug "dir::2new - Entering dir::2new current_env $filename"
		# Now I need to know the projected filetype
		# And the name of the future file
		set new_filetype [fas_get_value filetype]
		set new_filename [fas_get_value new_filename]
	
		# For security reasons, I just take the end of
		# new_filename (after last /)
		set new_filename [string trim [file tail $new_filename]]
		global conf

		# Is it on extension or not
		set ON_EXTENSION_FLAG 0
		if { $new_filetype == [translate "On extension"] } {
			# Getting the extension
			set new_filetype [guess_filetype $new_filename conf fas_env]
		 	set ON_EXTENSION_FLAG 1
			fas_debug "dir::2new - guessed filetype is $new_filetype"
		}
		# Next is the filetype a known one ?
		# AL 17/01/2006 - I think the newt lines are useless
		#global filetype_list
		#if { [lsearch $filetype_list $new_filetype] >= 0 } {
		#	fas_debug "dir::2new - found $new_filetype in $filetype_list"
			#OK it is a known filetype
			# Does a "new" function exists in the corresponding namespace ?
			# Or is there a method "new" of the class ?
		# 	set ON_EXTENSION_FLAG 1
		#	fas_debug "dir::2new - guessed filetype is $new_filetype"
		#}
		# Next is the filetype a known one ?
		global filetype_list
		if { [lsearch $filetype_list $new_filetype] >= 0 } {
			fas_debug "dir::2new - found $new_filetype in $filetype_list"
			#OK it is a known filetype
			# Does a "new" function exists in the corresponding namespace ?
			# Or is there a method "new" of the class ?
			#${new_filetype}::new $filename $new_filename $new_filetype $ON_EXTENSION_FLAG fas_env conf
			if { [catch { ${new_filetype}::new  fas_env conf $filename $new_filename $new_filetype $ON_EXTENSION_FLAG } new_error ] } {
				# There was an error, I suppose that 
				# the new method does not exist
				# I consider that there is no need to process
				# the new order
				set new::done 1
				fas_display_error "[translate "It was not possible to create a file of type"] $new_filetype<BR>$new_error" fas_env -f $filename 
			}
		} else {
			# There was an error, the filetype is unknown
			# I consider that there is no need to process
			# the new order
			set new::done 1
			fas_display_error "[translate "Unknown filetype"] $new_filetype" fas_env -f $filename 
		}
	}

	proc 2edit_form { current_env filename } {
		fas_debug "dir::2edit_form - current_env "
		upvar $current_env env
		global conf
		# chunk_string is used when displaying list by chunks.
		# I put there all the elements usefull for creating the display url
		set chunk_string "action=edit_form&"

		# The directory is its own dependency
		fas_depend::set_dependency $filename file

		# Template name may come from the env, then I take it
		fas_depend::set_dependency $filename env

		# First I need some informations 
		set display [fas_get_value display -default "filetype,shortname,extension,title,Copy,Edit,Delete,Properties,Allow,Candidate_order"]
		append chunk_string "display=${display}&"
		set order [fas_get_value order -default ""]
		append chunk_string "order=${order}&"
		set extension_list [fas_get_value extension_list -default "*"]
		append chunk_string "extension_list=${extension_list}&"
		set colnber [fas_get_value colnber -default 1]
		append chunk_string "colnber=${colnber}&"
		set reverse [fas_get_value colnber -default 0]
		append chunk_string "reverse=${reverse}&"
		# Do I need to substitute or not the START_FORM END_FORM block
		set form [fas_get_value form -default 0]
		append chunk_string "form=${form}&"
		# Do I want the ADD block on start ?
		set noadd [fas_get_value noadd -default 0]
		append chunk_string "noadd=${noadd}&"
		# Is there a form_desired, and should I propose
		# a display of only these comp_files
		set form_desired [fas_get_value dir.comp.desired_form -default ""]
		append chunk_string "form_desired=${form_desired}&"
		# Now the title
		set title [fas_get_value dir.title -default "[translate Directory] [rm_root $filename]"]
		append chunk_string "title=${title}&"
		# Do I do an ordering with a number ?
		set numorder [fas_get_value numorder -default "0"]
		append chunk_string "numorder=${numorder}&"


		# Do I want to just show a part of the files or all of it
		set linestoshow [fas_get_value dir.linestoshow -default -1]
		append chunk_string "linestoshow=${linestoshow}&"
		set chunk [fas_get_value chunk -default 0]

		set FORM_DESIRED_FLAG 0
		if { $form_desired != "" } {
			set FORM_DESIRED_FLAG 1
		}
		set display_list [split $display ","]
		set file_lol [get_file_lol $filename env -w $display_list -o $order -f $extension_list -c $form_desired -r $reverse -n $numorder]

		set message [fas_get_value message -default ""]
		append chunk_string "message=${message}"
		#fas_debug "dir::2edit_form - display_file_lol file_lol -> $file_lol  --- display_list -> $display_list --- colnber -> $colnber --- message -> $message --- filename -> $filename --- noadd -> $noadd --- form_desired -> $form_desired"
		set content [display_file_lol $file_lol env -title "$title" -d $display_list -c $colnber -m $message -r [rm_root $filename] -f $form -n $noadd -l $linestoshow -h $chunk -s $chunk_string]
	        #FIXME
		#set env(comp.comp) [get_comp_name env dir.edit_form]
		#fas_debug "dir::2edit_form - env(comp.comp) -> $env(comp.comp)"
		return $content
	}

	proc 2flatten { current_env filename } {
		fas_depend::set_dependency 1 always
		return ""
	}

	proc 2index { current_env filename } {
		fas_depend::set_dependency 1 always
		return ""
	}

	proc 2upload { current_env filename } {
		fas_depend::set_dependency 1 always
		return ""
	}

	proc 2nice_fax_name { current_env filename } {
		upvar $current_env fas_env
		fas_debug "dir::2nice_fax_name - entering"
		# Special action for directories coming from efax-gtk and 
		# containing a fax. The name of such a directory is :
		# 031230184157 - meaning : October, 30 2003 at 18:41:57
		# There are also interesting informations in the description
		# file of the directory. I try to take all that and use it.
		# filename is to be converted
		if { [regexp {([01-9][01-9])([01-9][01-9])([01-9][01-9])([01-9][01-9])([01-9][01-9])([01-9][01-9])} $filename match year month day hour minutes seconds] } {
			set to_change [file tail $filename]
			set year "20${year}"

			# getting the description file
			set info ""
			set description_filename [file join $filename Description]
			fas_debug "dir::2nice_fax_name - description_filename : $description_filename"
			if { [file readable $description_filename] } {
				fas_debug "dir::2nice_fax_name - readable $description_filename"
				if { ![catch {set fid [open $description_filename]}] } {
					fas_debug "dir::2nice_fax_name - reading $description_filename"
					set info [read $fid]
					fas_debug "dir::2nice_fax_name - info -> $info"
					close $fid
				}
			}

			if { [llength [info commands "[international::language]::fax_date"]] > 0 } {
				set result "[translate "Received on"] [[international::language]::fax_date $year $month $day $hour $minutes $seconds] - $info"
			} else {
				set result "[translate "Received on"] ${year}/${month}/${day} at ${hour}:${minutes}:${seconds} - $info"
			}
		} else {
			set result "Not a fax directory"
		}
		fas_debug "dir::2nice_fax_name - result is $result"
		return $result
	}

	# Allow to generate an xml xspf file giving the list of graphical files
	# in a directory (gif, jpg, png). Then this file may be given to 
	# the image rotator for having a list of files.
	# The use is something like :
	#<html>
	# <head>
        #  <script type="text/javascript" src="ufo.js"></script>
	# </head>
	# <body style="margin:50px;">
        #  <p id="player"><a href="http://www.macromedia.com/go/getflashplayer">Get the Flash Player</a> to see this player.</p>
        #  <script type="text/javascript">
        #        var FO = {      movie:"imagerotator.swf",width:"300",height:"400",majorversion:"7",build:"0",bgcolor:"#FFFFFF",flashvars:"file=/ucome.rvt%3Ffile%3D/any/rool/cinema/images%26action%3Dxspf&shownavigation=true&transition=random&backcolor=0xCCCCCC" };
        #        UFO.create(FO, "player");
        #  </script>
	# </body>
	#</html>
	# An action xspf_html must be made for generating this file
	proc 2xspf { current_env filename } {
		upvar $current_env fas_env
		fas_fastdebug {dir::2xspf entering with $filename}

		# So here I get the list of jpg, gif and png files
		# I create a corresponding xspf file with a section for each
		# graphic file.

		set file_list [glob -nocomplain -directory $filename *.png *.gif *.jpg]
		set content {<playlist version="1" xmlns="http://xspf.org/ns/0/">
        <trackList>
}
		if { [llength $file_list ] > 0 } {
			# OK I generate it
			foreach FILE $file_list {
				set export_FILE [rm_root $FILE]
				append content "                <track>
                        <title>${export_FILE}</title>
                        <creator>AL</creator>
			<location>[fashtml::to_right_url "fas:$export_FILE" "" ""]$export_FILE</location> 
                        <info></info>
                </track>
"
			}
		}
		append content "        </trackList>
</playlist>"
		return $content
	}
				
	

	proc content_display { current_env content } {
		_cgi_http_head_implicit
		puts "$content"
	}

	# Basically, when arriving on a dir, I will jump at display.
	# If it is possible to show a index.html or corresponding
	# file, then I will do it. Else I will show some idiot dir content.
	proc display { current_env filename } {
		# A procedure for just displaying the file in html directly
		upvar $current_env fas_env
		global conf
		set FOUND 0

		if { [info exists fas_env(dir.file_index)] } {
			set file [file join $filename $fas_env(dir.file_index)]
			array unset fas_env
			read_full_env $file fas_env
			set filetype [guess_filetype $file conf fas_env]
			set FOUND 1
		} else {
			# BEWARE, I should have the list of possible
			# extensions, and test which one have an index
			set potential_list [glob -nocomplain [file join $filename "index.*"]]
			fas_debug "dir::display - found a directory - list of potential file is : $potential_list"
			if { [llength $potential_list] > 0 } {
				set file [lindex $potential_list 0]
				array unset fas_env
				read_full_env $file fas_env
				set filetype [guess_filetype $file conf fas_env]
				set FOUND 1
			} else {
		 		# well I just let things as they are
				set FOUND 0
			}
		}


		if $FOUND {
			fas_debug "dir::display -> display_file $filetype $file fas_env conf"
			# I think that I must update fas_env with the good values
			display_file $filetype $file fas_env conf
		} else {
			if { [catch {open $filename} fid] } {
				error "dir::display - could not open $filename"
			} else {
				set file_list [glob -nocomplain [file join "filename" "*"]]
				set content "<center><h1>$filename</h1></center>"

				foreach file $file_list {
					append content "\n$file<br>"
				}
				cgi_eval {
					# BEWARE TO BE IMPROVED
					# It would be better with a template
					cgi_html {
						cgi_body "bgcolor=#ffffff" {
							cgi_puts "$content"
						}
					}
				}
			}
		}
	}

	proc content  { current_env filename } {
		# A procedure for just displaying the directory
		upvar $current_env fas_env
		global conf
		set FOUND 0

		set content ""

		if { [info exists fas_env(dir.file_index)] } {
			set file [file join $filename $fas_env(dir.file_index)]
			set filetype [guess_filetype $file conf fas_env]
			set FOUND 1
		} else {
			# BEWARE, I should have the list of possible
			# extensions, and test which one have an index
			set potential_list [glob -nocomplain [file join $filename "index.*"]]
			fas_debug "dir::content - found a directory - list of potential file is : $potential_list"
			if { [llength $potential_list] > 0 } {
				set file [lindex $potential_list 0]
				set filetype [guess_filetype $file conf fas_env]
				set FOUND 1
			} else {
		 		# well I just let things as they are
				set FOUND 0
			}
		}


		if $FOUND {
			fas_debug "dir::content -> display_file $filetype $file fas_env conf"
			set content [display_file $filetype $file fas_env conf -nod]
		} else {
			if { [catch {open $filename} fid] } {
				set content "dir::display - could not open $filename"
			} else {
				set file_list [glob -nocomplain [file join "filename" "*"]]
				set content "<center><h1>$filename</h1></center>"

				foreach file $file_list {
					append content "\n$file<br>"
				}
				set final_content "$content"
			}
		}
		return $content
	}
	
	# recursively process the directory
	proc 2txt4index { current_env filename } {
		upvar $current_env fas_env
		fas_debug "dir::2txt4index with $filename"
		process_dir current_env $filename ""
		global _cgi_uservar
		unset _cgi_uservar
		set _cgi_uservar(message) "[translate "Successfull conversion to indexable text of "] $filename"
		global DEBUG
		if $DEBUG {
			set _cgi_uservar(debug) $DEBUG
		}
		set _cgi_uservar(action) edit_form
		global conf
		display_file dir $filename fas_env conf
		fas_exit
	}

	proc copy_graph { current_env root_dir relative_dir } {
		upvar $current_env fas_env
		global conf
		variable errors
		variable errstr
		set ori_dir [file join $root_dir $relative_dir]

		fas_debug "<font color=red>dir::copy_graph : $ori_dir</font>"
		set file_list [glob -nocomplain -types {f} -- [file join $ori_dir *]]
		fas_debug "<font color=red>dir::copy_graph found - $file_list</font>"
		foreach file $file_list {
			read_full_env $file current_file_env
			set file_type [guess_filetype $file conf current_file_env ]
			if { ![info exists current_file_env(txt4index.ignore)] &&  $file_type != "dir" } {
				fas_debug "<font color=red>dir::copy_graph - filetype of $file is $file_type</font>"
				# it is not a graphic file, so I convert it to txt4index
				global _cgi_uservar
				unset _cgi_uservar
				set _cgi_uservar(action) "txt4index"
				display_file $file_type $file current_file_env conf -nod
			}
		}
	}

	# Going through directory and looking at the files
	proc process_dir { current_env root_dir relative_dir } {
		upvar $current_env fas_env

		# First processing the file of the current directory
		# Skipping CVS directory
		if { [file tail $relative_dir] != "CVS" } {
			copy_graph fas_env $root_dir $relative_dir
		}

		# Now looking for the sub directories
		# Dummy entry for the unset
		set current_dir_env(bad) 0
		fas_debug "<font color=green>dir::process_dir - $root_dir, $relative_dir</font>"
		# The level variable is just for debug :
		# it allows to see how deep you are in the tree
		# and when you come back (especially when you come back)
		variable level
		fas_debug "<font color=green>dir::process_dir - level $level</font>"
		incr level

		set dir_list [glob -nocomplain -types {d} -- [file join $root_dir $relative_dir *]]
		fas_debug "<font color=green>dir::process_dir - current dir_list is $dir_list</font>"
		foreach dir $dir_list {
			# skip CVS directories
			if {([file tail $dir] != "CVS") && ([file tail $dir] != "CVS/")} { 
				# First, I load the corresponding env
				unset current_dir_env
				read_full_env $dir current_dir_env
				if { ![info exists current_dir_env(txt4index.ignore)] } {
					set relative_dir [string trimleft [string range $dir [string length $root_dir] end] "/"]
					fas_debug "<font color=green>dir::process_dir - processing relative_dir $relative_dir</font>"
					process_dir current_dir_env $root_dir $relative_dir
				}
			}
		}
		fas_debug "<font color=green>dir::process_dir - leaving level $level</font>"
		incr level -1
	}
		
	# copy dir and his .mana/.val in dest_dirname
	proc copy_archive { current_env filename dest_dirname } {
		upvar $current_env env
		
		fas_debug "dir::copy_archive - $current_env $filename $dest_dirname"

		set current_dir [rm_root2 $filename]
		if { ![file exists "$dest_dirname$current_dir"]} { 
			if [file isdirectory $filename] {
				regexp "(.*)/?$" $current_dir trash tmp
				regexp "(^/(?:\[^/\]*/)*)\[^/\]" $current_dir trash parent_dir  
				if { $parent_dir != "/" } {
					dir::copy_archive env [add_root2 $parent_dir] $dest_dirname 
				}
				if [catch {file mkdir "$dest_dirname$current_dir"}] {
					log::log error "Error while create [rm_root2 $dest_dirname$current_dir]"
				}
				if [file isdirectory "${filename}/.mana" ] { 
					if [catch {file mkdir "$dest_dirname$current_dir/.mana"}] {
						log::log warning "error while create [rm_root2 $dest_dirname$current_dir/.mana]"
					}
					if [catch {file copy "[add_root2 $current_dir]/.mana/.val" "$dest_dirname$current_dir/.mana/.val"}] {
						log::log warning "error while copy [rm_root2 $dest_dirname$current_dir/.mana/.val]"
					}
				}
			}
		}
	}
}
