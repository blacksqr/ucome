# no extensions for copy_form
lappend filetype_list copy_form

# And now all procedures for txt. How to translate into tmpl or html,
# how to display pure txt.
namespace eval copy_form {
	# At the end of the copy I set it at 1.
	# I will use it when changing of state
	set done 0
	global INIT_ACTION
	eval $INIT_ACTION

	proc new_type { current_env filename } {
		# When a txt is met, in what filetype will it be by default
		# translated ?
		# This is the default answer
		set result comp
		# copy_form type must appear only once after that when
		# "normal" filetype tests for it, it must not appear.
		# new_type is the only function executed when looking
		# for a file. So I must put there the setting of this
		# flag.
		variable done 
		set done 1
		return $result
	}

	# List of possible types in which this file type may be converted
	# If this function is not defined, it is a final type that can
	# not be converted
	proc new_type_list { } {
		return [list comp fashtml ]
	}

	# This procedure returns the list of important session variables for
	# this type of file
	# If this function is not defined, no one are important
	proc important_session_keys { } {
		# not any one
		return [list]
	}

	# Return the list of environment variables that are important
	# If this function is not defined, it is a final type that can
	# not be converted
	proc env { args } {
		set env_list ""
		lappend env_list [list "copy_form.template" "Template used when preparing a file copy ." webmaster]
		return $env_list
	}

	proc 2comp { current_env args } {
		fas_debug "copy_form::2comp - $args"
		upvar $current_env env
		array set tmp ""
		set tmp(content.content) [extract_body [eval 2fashtml env $args]]
		return "[array get tmp]"
	}

	proc content2comp { current_env args } {
		fas_debug "copy_form::content2comp - $args"
		upvar $current_env env
		array set tmp ""
		set tmp(content.content) [extract_body [eval content2fashtml env $args ]]
		return "[array get tmp]"
	}
	
	# This procedure will translate create the html text for a copy
	proc 2fashtml { current_env filename } {
		upvar $current_env fas_env
		global FAS_VIEW_CGI
		# First the dependencies :
		fas_depend::set_dependency $filename file
		# First, I will use treedir after, and I am must prepare
		# the url to use when cliking on a directory.
		# treedir is obsolete, preparing for comp and treedir action
		#set treedir::local_conf(url_start) "?action=copy_form&file=[rm_root $filename]&dir="

		# Getting the template
		set template_name [fas_name_and_dir::get_template_name fas_env copy_form.template]
		fas_depend::set_dependency $template_name file

		atemt::read_file_template_or_cache "COPY_TEMPLATE" "$template_name" 

		# Setting some blocks in the template
		atemt::set_html FILENAME "[rm_root $filename]"
		atemt::set_html TITLE "[translate "Copy form for"] [rm_root $filename]"

	        # Preparing the variables
	        #set icons_url [fas_get_value icons_url -default "fas:/icons"]
		set icons_url [fas_name_and_dir::get_icons_dir]
	        set export_filename [rm_root $filename]
	        set dir [rm_root [file dirname $filename]]
		set target_dir [fas_get_value dir -default "$dir"]
		# No reason to do substitution here
		set atemt::_atemt(COPY_TEMPLATE) [atemt::atemt_subst -block FORM -block TITLE -block FILENAME COPY_TEMPLATE]
		# Here there is filename and dir to substitute
		return [atemt::atemt_subst -end COPY_TEMPLATE]
	}

	# This procedure will translate a string in txt2ml format into html 
	proc content2fashtml { current_env content args } {
		return "<html><body><center><b>[translate "It is not possible to copy a content. It must be a filename."]</b></center></body></html>"
	}
}
