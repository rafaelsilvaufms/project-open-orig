# /packages/intranet-trans-invoices/www/new-2.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    Receives a list of projects and displays all Tasks of these projects,
    ordered by project, allowing the user to modify the "billable units".
    Provides a button to advance to "new-3.tcl".

    @param order_by project display order 
    @param include_subprojects_p whether to include sub projects
    @param status_id criteria for project status
    @param type_id criteria for project_type_id
    @param letter criteria for im_first_letter_default_to_a(ug.group_name)
    @param start_idx the starting index for query
    @param how_many how many rows to return

    @author frank.bergmann@poject-open.com
} {
    { select_project:multiple }
    invoice_currency
    { return_url ""}
}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set current_user_id $user_id

set page_focus "im_header_form.keywords"
set view_name "invoice_tasks"

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"
set required_field "<font color=red size=+1><B>*</B></font>"

if {![im_permission $user_id add_invoices]} {
    ad_return_complaint "Insufficient Privileges" "
    <li>You don't have sufficient privileges to see this page."    
}

# ---------------------------------------------------------------
# 3. Check the consistency of the select project and get client_id
# ---------------------------------------------------------------

# select tasks only from the selected projects ...
# and form a $projects_where_clause that allows to select
# only from these projects.
set in_clause_list [list]
foreach selected_project $select_project {
        lappend in_clause_list $selected_project
}
set projects_where_clause "and p.project_id in ([join $in_clause_list ","])"


# check that all projects are from the same client
set num_clients [db_string select_num_clients "
select
        count(*)
from
        (select distinct customer_id
        from im_projects
        where project_id in ([join $in_clause_list ","])
        )
"]

if {$num_clients > 1} {
        ad_return_complaint "You have selected multiple clients" "
        <li>You have selected multiple clients.<BR>
            Please backup and restrict the selection to the projects of a single client."
}


# now we know that all projects are from a single customer:
set customer_id [db_string select_num_clients "select distinct customer_id from im_projects where project_id in ([join $in_clause_list ","])"]


# ---------------------------------------------------------------
# Generate SQL Query for the list of tasks (invoicable items)
# ---------------------------------------------------------------


set sql "
select 
	p.project_name,
	p.project_path,
	p.project_path as project_short_name,
	t.task_id,
	t.task_units,
	t.task_name,
	t.billable_units,
	t.task_uom_id,
	t.task_type_id,
	t.project_id,
	im_category_from_id(t.task_uom_id) as uom_name,
	im_category_from_id(t.task_type_id) as type_name,
	im_category_from_id(t.task_status_id) as task_status
from 
	im_trans_tasks t,
	im_projects p
where 
	t.project_id = p.project_id
	and t.invoice_id isnull
        and t.task_status_id in (
                select task_status_id
                from im_task_status
                where upper(task_status) not in (
                        'CLOSED','INVOICED','PARTIALLY PAID',
                        'DECLINED','PAID','DELETED','CANCELED'
                )
        )
        $projects_where_clause
order by
	project_id, task_id
"

set task_table "
<tr> 
  <td class=rowtitle align=middle>[im_gif help "Include in Invoice"]</td>
  <td class=rowtitle>Task Name</td>
  <td class=rowtitle>Units</td>
  <td class=rowtitle>Billable Units</td>
  <td class=rowtitle>  
    UoM [im_gif help "Unit of Measure"]
  </td>
  <td class=rowtitle>Type</td>
  <td class=rowtitle>Status</td>
</tr>
"

set task_table_rows ""
set ctr 0
set colspan 11
set old_project_id 0
db_foreach select_tasks $sql {

    # insert intermediate headers for every project
    if {$old_project_id != $project_id} {
	append task_table_rows "
		<tr><td colspan=$colspan>&nbsp;</td></tr>
		<tr><td class=rowtitle colspan=$colspan>
	          <A href=/intranet/projects/view?group_id=$project_id>$project_short_name</A>:
	          $project_name
	        </td></tr>\n"
	set old_project_id $project_id
    }

    append task_table_rows "
	<tr $bgcolor([expr $ctr % 2])> 
          <td align=middle>
            <input type=checkbox name=include_task value=$task_id checked>
          </td>
	  <td align=left>$task_name</td>
	  <td align=right>$task_units</td>
	  <td align=right>$billable_units</td>
	  <td align=right>$uom_name</td>
	  <td>$type_name</td>
	  <td>$task_status</td>
	</tr>"
    incr ctr
}

if {![string equal "" $task_table_rows]} {
    append task_table $task_table_rows
} else {
    append task_table "<tr><td colspan=$colspan align=center>No tasks found</td></tr>"
}

set deselect_button_html "
    <tr><td colspan=7 align=right>
      <input type=submit name=submit value='Select Tasks for Invoicing'>
    </td></tr>
    <tr><td>&nbsp;</td></tr>
"

# ---------------------------------------------------------------
# 10. Join all parts together
# ---------------------------------------------------------------

set page_body "
[im_invoices_navbar "none" "/intranet/invoicing/index" "" "" [list]]

<form action=new-3 method=POST>
[export_form_vars customer_id invoice_currency return_url]

  <!-- the list of tasks (invoicable items) -->
  <table cellpadding=2 cellspacing=2 border=0>
    $task_table
    $deselect_button_html
  </table>

</form>
"

db_release_unused_handles
doc_return  200 text/html [im_return_template]
