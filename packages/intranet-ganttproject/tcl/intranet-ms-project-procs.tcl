# /packages/intranet-ganttproject/tcl/intranet-ganttproject.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    Integrate ]project-open[ tasks and resource assignations
    with GanttProject and its data structure

    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# 
# ----------------------------------------------------------------------

ad_proc -public im_ms_project_write_subtasks { 
    { -default_start_date "" }
    { -default_duration "" }
    project_id
    doc
    tree_node 
    outline_level
    outline_number
    id_name
} {
    Write out all the specific subtasks of a task or project.
    This procedure asumes that the current task has already 
    been written out and now deals with the subtasks.
} {
    # Why is id_name passed by reference?
    upvar 1 $id_name id

    # Get sub-tasks in the right sort_order
    set object_list_list [db_list_of_lists sorted_query "
	select	p.project_id as object_id,
		o.object_type,
		p.sort_order
	from	acs_objects o,
		im_projects p
		LEFT OUTER JOIN im_gantt_projects gp ON (p.project_id = gp.project_id)
	where	p.project_id = o.object_id
		and parent_id = :project_id
		and p.project_status_id not in ([im_project_status_deleted])
	order by 
		coalesce(gp.xml_id::integer, 0),
		p.sort_order
    "]

    incr outline_level
    set outline_sub 0
    foreach object_record $object_list_list {
	incr outline_sub
	set object_id [lindex $object_record 0]

	if {$outline_level==1} {
	    set oln "$outline_sub"
	} else {
	    set oln "$outline_number.$outline_sub"
	}

	incr id

	im_ms_project_write_task  \
		-default_start_date $default_start_date  \
		-default_duration $default_duration  \
		$object_id  \
		$doc \
		$tree_node \
		$outline_level \
		$oln \
		id
    }
}

ad_proc -public im_ms_project_write_task { 
    { -default_start_date "" }
    { -default_duration "" }
    project_id
    doc
    tree_node 
    outline_level
    outline_number
    id_name
} {
    Write out the information about one specific task and then call
    a recursive routine to write out the stuff below the task.
} {
    upvar 1 $id_name id
    set org_project_id $project_id

    if { [security::secure_conn_p] } {
	set base_url "https://[ad_host][ad_port]"
    } else {
	set base_url "http://[ad_host][ad_port]"
    }
    set task_view_url "$base_url/intranet-timesheet2-tasks/new?task_id="
    set project_view_url "$base_url/intranet/projects/view?project_id="

    # ------------ Get everything about the project -------------
    if {![db_0or1row project_info "
	select  p.*,
		t.*,
		o.object_type,
		p.start_date::date || 'T' || p.start_date::time as start_date,
		p.end_date::date || 'T' || p.end_date::time as end_date,
		(p.end_date::date 
			- p.start_date::date 
			- 2*(next_day(p.end_date::date-1,'FRI') 
			- next_day(p.start_date::date-1,'FRI'))/7
			+ round((extract(hour from p.end_date) - extract(hour from p.start_date)) / 8.0)
		) * 8 AS duration_hours,
		c.company_name,
		g.*
	from    im_projects p
		LEFT OUTER JOIN im_timesheet_tasks t ON (p.project_id = t.task_id)
		LEFT OUTER JOIN im_gantt_projects g ON (p.project_id = g.project_id),
		acs_objects o,
		im_companies c
	where   p.project_id = :project_id
		and p.project_id = o.object_id
		and p.company_id = c.company_id
    "]} {
	ad_return_complaint 1 [lang::message::lookup "" intranet-ganttproject.Project_Not_Found "Didn't find project \#%project_id%"]
	return
    }

    # Make sure some important variables are set to default values
    # because empty values are not accepted by Microsoft Project:
    #
    if {"" == $percent_completed} { set percent_completed "0" }
    if {"" == $priority} { set priority "1" }
    if {"" == $start_date} { set start_date $default_start_date }
    if {"" == $start_date} { set start_date [db_string today "select to_char(now(), 'YYYY-MM-DD')"] }
    if {"" == $duration_hours} { 
	set duration_hours $default_duration
    }
    if {"" == $duration_hours || [string equal $start_date $end_date] } { 
	set duration_hours 0 
    }

    set task_node [$doc createElement Task]
    $tree_node appendChild $task_node

    # minimal set of elements in case this hasn't been imported before
    if {[llength $xml_elements] == 0} {
	set xml_elements {
		UID ID 
		Name Type 
		OutlineNumber OutlineLevel Priority 
		Start Finish 
		Work RemainingWork
		Duration 
		RemainingDuration
		DurationFormat
		CalendarUID 
		PercentComplete
		FixedCostAccrual
	}
    }

    # Add the following elements to the xml_elements always
    if {[lsearch $xml_elements "PredecessorLink"] < 0} {
	lappend xml_elements "PredecessorLink"
    }

    set predecessors_done 0
    foreach element $xml_elements { 

	set attribute_name [plsql_utility::generate_oracle_name "xml_$element"]
	switch $element {
		Name			{ set value $project_name }
		Type			{   if {[info exists xml_type] && $xml_type!=""} {
						set value $xml_type
					    } else {
						set value 0 
					    }
					}
		OutlineNumber		{ set value $outline_number }
		OutlineLevel		{ set value $outline_level }
		Priority		{ set value 500 }
		Start			{ set value $start_date }
		Finish			{ set value $end_date }
		Duration {
			# Check if we've got a duration defined in the xml_elements.
			# Otherwise (export without import...) generate a duration.
			set value "PT$duration_hours\H0M0S" 
			# if {[info exists $attribute_name ] } { set value [expr $$attribute_name] }
		}
		DurationFormat		{ set value 7 }
		RemainingDuration {
			set remaining_duration_hours [expr round($duration_hours * (100.0 - $percent_completed) / 100.0)]
			set value "PT$remaining_duration_hours\H0M0S" 
			# if {[info exists $attribute_name ] } { set value [expr $$attribute_name] }
		}
		Notes			{ set value $note }
		PercentComplete		{ set value $percent_completed }
		PredecessorLink	{ 
			if {$predecessors_done} { continue }
			set predecessors_done 1

			# Add dependencies to predecessors 
			set dependency_sql "
				SELECT DISTINCT
					gp.xml_uid as xml_uid_ms_project,
					gp.project_id as xml_uid
				FROM	im_timesheet_task_dependencies ttd
					LEFT OUTER JOIN im_gantt_projects gp ON (ttd.task_id_two = gp.project_id)
				WHERE	ttd.task_id_one = :task_id and
					ttd.dependency_type_id = [im_timesheet_task_dependency_type_depends] and
					ttd.task_id_two <> :task_id
			"

			db_foreach dependency $dependency_sql {
			    $task_node appendXML "
				<PredecessorLink>
					<PredecessorUID>$xml_uid</PredecessorUID>
					<Type>1</Type>
					<CrossProject>0</CrossProject>
					<LinkLag>0</LinkLag>
					<LagFormat>7</LagFormat>
				</PredecessorLink>
			    "
			}
			continue
		}
		UID			{ set value $org_project_id }
		ACWP - \
		ActualCost - \
		ActualDuration - \
		ActualOvertimeCost - \
		ActualOvertimeWork - \
		ActualWork - \
		BCWP - \
		BCWS - \
		CV - \
		CommitmentType - \
		ConstraintType - \
		Cost - \
		CreateDate - \
		Critical - \
		CustomProperty - \
		Depend - \
		EarlyFinish - \
		EarlyStart - \
		EarnedValueMethod - \
		EffortDriven - \
		Estimated - \
		ExtendedAttribute - \
		ExternalTask - \
		FinishVariance - \
		FixedCost - \
		FreeSlack - \
		HideBar - \
		IgnoreResourceCalendar - \
		IsPublished - \
		IsSubproject - \
		IsSubprojectReadOnly - \
		LateFinish - \
		LateStart - \
		LevelAssignments - \
		LevelingCanSplit - \
		LevelingDelay - \
		LevelingDelayFormat - \
		Milestone - \
		OverAllocated - \
		OvertimeCost - \
		OvertimeWork - \
		PercentWorkComplete - \
		PhysicalPercentComplete - \
		Recurring - \
		RegularWork - \
		RemainingCost - \
		RemainingOvertimeCost - \
		RemainingOvertimeWork - \
		RemainingWork - \
		ResumeValid - \
		Rollup - \
		StartVariance - \
		Summary - \
		Task - \
		TotalSlack - \
		Work - \
		WorkVariance - \
		Xxxx {
		    # Skip these ones
		    continue 
		}
		default {
			if {[info exists $attribute_name ] } {
			    set value [expr $$attribute_name]
			} else {
			    set value 0
			}
		}
	}

	# Setup reasonable values for tasks not imported from MS-Project
	if {"" == $value} {
	    ns_log Notice "im_ms_project_write_task: Error: Undefined value for '$element'"
	    switch $element {
		UID					{ set value $org_project_id }
		ID					{ set value $org_project_id }
		Duration - RemainingDuration - Work - RemainingWork	{ set value "PT24H0M0S" }
		PercentComplete - PercentWorkComplete	{ set value $percent_completed }
		FixedCostAccrual			{ set value 3 }
	    }
	}

	# Special logic for elements
	switch $element {
	    FixedCostAccrual {
		# I'm not sure what this field is good for, 
		# but any value except for 3 gives an error...
		set value 3
	    }
	}

	ns_log Notice "im_ms_project_write_task: Adding element='$element' with value='$value'"
	$task_node appendFromList [list $element {} [list [list \#text $value]]]
    }

    # Disabled storing the ]po[ task IDs.
    # Instead, we can use the UID of MS-Project, which survives updates of the project
    set ttt {    
	    $task_node appendXML "
			<ExtendedAttribute>
			<UID>$project_id</UID>
			<FieldID>188744006</FieldID>
			<Value>$project_nr</Value>
			</ExtendedAttribute>
		"
	    $task_node appendXML "
			<ExtendedAttribute>
			<UID>$project_id</UID>
			<FieldID>188744007</FieldID>
			<Value>$project_id</Value>
			</ExtendedAttribute>
		"
    }

    im_ms_project_write_subtasks \
	-default_start_date $start_date \
	-default_duration $duration_hours \
	$project_id \
	$doc \
	$tree_node \
	$outline_level \
	$outline_number \
	id
}

