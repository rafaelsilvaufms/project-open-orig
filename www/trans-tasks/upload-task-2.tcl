# /packages/intranet-translation/www/upload-task-2.tcl
#
# Copyright (C) 2004 Project/Open
# All rights reserved (this is not GPLed software!).
# Please check http://www.project-open.com/ for licensing
# details.

ad_page_contract {
    insert a file into the file system
} {
    project_id:integer
    task_id:integer
    return_url
    upload_file
    {file_title:trim ""}
} 

# ---------------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set project_path [im_filestorage_project_path $project_id]

set page_title "[_ intranet-translation.Upload_Successful]"
# Set the context bar as a function on whether this is a subproject or not:
if {[im_permission $user_id view_projects]} {
    set context_bar [im_context_bar [list /intranet/projects/ "[_ intranet-translation.Projects]"] [list "/intranet/projects/view?group_id=$project_id" "[_ intranet-translation.One_project]"] $page_title]
} else {
    set context_bar [im_context_bar [list /intranet/projects/ "[_ intranet-translation.Projects]"] $page_title]
}


# ---------------------------------------------------------------------
# SQL
# ---------------------------------------------------------------------

# get everything about the specified task
set task_sql "
select
	t.*,
	im_category_from_id(t.task_status_id) as task_status,
	im_category_from_id(t.source_language_id) as source_language,
	im_category_from_id(t.target_language_id) as target_language
from
	im_trans_tasks t
where
	t.task_id=:task_id
	and t.project_id=:project_id"

if {![db_0or1row task_info_query $task_sql] } {
    ad_return_complaint 1 "<li>[_ intranet-translation.lt_Couldnt_find_the_spec]"
    return
}

# Get the overall permissions
im_translation_task_permissions $user_id $task_id view read write admin

# Check for permissions according to the im_trans_tasks state engine:
# Check if the user is a freelance who is allowed to
# upload a file for this task, depending on the task
# status (engine) and the assignment to a specific phase.
#
set upload_list [im_task_component_upload $user_id $admin $task_status_id $source_language $target_language $trans_id $edit_id $proof_id $other_id]
set download_folder [lindex $upload_list 0]
set upload_folder [lindex $upload_list 1]
if {"" == $upload_folder} {
    ad_return_complaint 1 "
	<li>[_ intranet-translation.lt_You_are_not_allowed_t]"
    return
}

# Get the file from the user.
# number_of_bytes is the upper-limit
set max_n_bytes [ad_parameter -package_id [im_package_filestorage_id] MaxNumberOfBytes "" 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
set filesize [file size $tmp_filename]

if { $max_n_bytes && ($filesize > $max_n_bytes) } {
    set util_commify_number_max_n_bytes [util_commify_number $max_n_bytes]
    ad_return_complaint 1 "[_ intranet-translation.lt_Your_file_is_larger_t_1]"
    return 0
}

# -------------------------------------------------------------------
# Check the the $upload_file is the same filename as the $task_name
# -------------------------------------------------------------------

ns_log Notice "upload_file=$upload_file"
ns_log Notice "task_name=$task_name"

set upload_file_pathes [split $upload_file "\\"]
set upload_file_len [expr [llength $upload_file_pathes]-1]
set task_name_pathes [split $task_name "/"]
set task_name_len [expr [llength $task_name_pathes]-1]

set upload_file_body [lindex $upload_file_pathes $upload_file_len]
set task_name_body [lindex $task_name_pathes $task_name_len]

ns_log Notice "upload_file_body=$upload_file_body"
ns_log Notice "task_name_body=$task_name_body"

# Make sure both filenames coincide to avoid translator errors
#
if {![string equal $upload_file_body $task_name_body]} {
    set error "<li>[_ intranet-translation.lt_Your_file_doesnt_coin]<br>
    [_ intranet-translation.lt_Your_file_upload_file]<br>
    [_ intranet-translation.lt_Expected_file_task_na]<br>
    [_ intranet-translation.lt_Please_check_your_inp]"
    ad_return_complaint "[_ intranet-translation.User_Error]" $error
    return
}

# -------------------------------------------------------------------
# Let's copy the file into the FS
# -------------------------------------------------------------------

# First make sure that subdirectories exist
set subfolders [split $task_name "/"]
set subfolder_len [expr [llength $subfolders]-1]
set subfolder_path ""
for {set i 0} {$i < $subfolder_len} {incr i} {
    set subfolder [lindex $subfolders $i]
    append subfolder_path "$subfolder/"

    set path "$project_path/$upload_folder/$subfolder_path"
    ns_log Notice "path=$path"

    if {![file isdirectory $path]} {
	if { [catch {
	    ns_log Notice "/bin/mkdir $path"
	    exec /bin/mkdir "$path"
	} err_msg] } {
	    # Probably some permission errors
	    ad_return_complaint "[_ intranet-translation.lt_Error_creating_subfol]" $err_msg
	    return
	}
    }
}


# Move the file
#
if { [catch {
    ns_log Notice "/bin/mv $tmp_filename $project_path/$upload_folder/$task_name"
    exec /bin/cp $tmp_filename "$project_path/$upload_folder/$task_name"
    ns_log Notice "/bin/chmod ug+w $project_path/$upload_folder/$task_name"
    exec /bin/chmod ug+w $project_path/$upload_folder/$task_name

} err_msg] } {
    # Probably some permission errors
    ad_return_complaint  "[_ intranet-translation.lt_Error_writing_upload_]"  $err_msg
    return
}

# Advance the status of the respective im_task.
#
im_trans_upload_action $task_id $task_status_id $task_type_id $user_id


set page_body "
<H2>[_ intranet-translation.Upload_Successful]</H2>
[_ intranet-translation.lt_Your_have_successfull]
<P><A href=\"$return_url\">[_ intranet-translation.lt_Return_to_Project_Pag]</A></P>
"

ad_return_template
return

