set ::conf(extension.password) password
set ::conf(extension.pass) password

lappend filetype_list password

namespace eval password {
	regsub -all "::" [namespace current] {} local_filetype
	global DOMP_PROCEDURES
	eval $DOMP_PROCEDURES


	proc clean_name { name } {
		# I remove all caracters that are bad
		regsub -all {[^A-Za-z01-9_\-]} $name {_} name
		return $name
	}

	proc new { current_env current_conf dirname filename filetype ON_EXTENSION_FLAG } {
		variable local_filetype
		fas_debug "${local_filetype}::new - _env current_conf"
		upvar $current_env fas_env
		upvar $current_conf fas_conf

		# I will just create a particular name here ?
		global _cgi_uservar
		variable local_conf
		set _cgi_uservar(comp.####) "[file join [fas_name_and_dir::get_comp_dir fas_env domp] $local_conf(comp)]"
		set _cgi_uservar(comp.lastname.content) "$filename"
		set final_filename "[clean_name [file tail $filename]].${local_filetype}"

		comp::new fas_env fas_conf $dirname $final_filename ${local_filetype} $ON_EXTENSION_FLAG
	}

	proc get_title { filename } {	
		global fas_env
		# I put the structure of the form in an array
		set title [translate "Problem in the user file"]
		set real_filename [fas_name_and_dir::get_real_filename password $filename fas_env]
		if { ![catch {read_env $real_filename form_content}] } {

			fas_debug_parray form_content "comp::get_title - form_content"
			# And I take content if it exists
			# OK, in theory, I should do a special function for each
			# different type. Load the corresponding form, look at 
			# the type of title, ... I find it boring.
			if { [info exists form_content(lastname.content)] } {
				set title $form_content(lastname.content)
			}
		}
		return $title
	}
}
