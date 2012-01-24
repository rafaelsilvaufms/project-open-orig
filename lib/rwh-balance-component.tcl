# /packages/intranet-timesheet2/www/absences/vacation-balance-component.tcl
#
# Copyright (C) 1998-2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

# ---------------------------------------------------------------
# 1. Page Contract
# ---------------------------------------------------------------

#ad_page_contract {
#    Shows the vacation balance for the user and the current year.
#    @author Frank Bergmann (frank.bergmann@project-open.com)
#} {
#    user_id_from_search:integer
#}

# ---------------------------------------------------------------
# 2. Defaults & Security
# ---------------------------------------------------------------

set current_user_id [ad_maybe_redirect_for_registration]
set date_format "YYYY-MM-DD"
set package_key "intranet-timesheet2"
set view_absences_p [im_permission $current_user_id "view_absences"]
set view_absences_all_p [im_permission $current_user_id "view_absences_all"]
set add_absences_p [im_permission $current_user_id "add_absences"]

set today [db_string today "select now()::date"]

if {!$view_absences_p && !$view_absences_all_p} { 
    return ""
}

set page_title [lang::message::lookup "" intranet-timesheet2.Rwh_Balance "Vacation Balance"]
set absence_base_url "/intranet-timesheet2/absences"
set return_url [im_url_with_query]
set user_view_url "/intranet/users/view"


set current_year [db_string current_year "select to_char(now(), 'YYYY')"]

set start_of_year "$current_year-01-01"
set end_of_year "$current_year-12-31"

set rwh_absence_id [db_string get_data "select category_id from im_categories where category = 'Reduction in Working Hours'" -default 0]

# ------------------------------------------------------------------
# User Info
# ------------------------------------------------------------------

db_0or1row user_info "
	select	u.user_id,
		e.*,
		im_name_from_user_id(u.user_id) as user_name
	from	cc_users u
		LEFT OUTER JOIN im_employees e ON e.employee_id = u.user_id
	where	u.user_id = :user_id_from_search
"

# ------------------------------------------------------------------
# 
# ------------------------------------------------------------------

list::create \
    -name rwh_balance \
    -multirow rwh_balance_multirow \
    -key absence_id \
    -checkbox_name checkbox \
    -selected_format "normal" \
    -class "list" \
    -main_class "list" \
    -sub_class "narrow" \
    -actions {
    } -elements {
        absence_name {
            label "[lang::message::lookup {} intranet-timesheet2.Name Name]"
            link_url_eval $absence_url
        }
	absence_type {
            label "[lang::message::lookup {} intranet-timesheet2.Type Type]"
	}
	start_date_pretty {
            label "[lang::message::lookup {} intranet-timesheet2.Start_Date Start]"
	}
	end_date_pretty {
            label "[lang::message::lookup {} intranet-timesheet2.End_Date End]"
	}
	duration_days {
            label "[lang::message::lookup {} intranet-timesheet2.Vacation_Days_Taken {Vacation Days Taken}]"
	}
    }

set vacation_sql "
	select
		a.*,
		substring(a.description from 1 for 40) as description_pretty,
		substring(a.contact_info from 1 for 40) as contact_info_pretty,
		to_char(a.start_date, :date_format) as start_date_pretty,
		to_char(a.end_date, :date_format) as end_date_pretty,
		im_name_from_user_id(a.owner_id) as owner_name
	from
		im_user_absences a
	where
		a.owner_id = :user_id_from_search and
		a.start_date <= :end_of_year and
		a.end_date >= :start_of_year and 
		a.absence_type_id = $rwh_absence_id
	order by
		a.start_date
"

set rwh_days_last_year [db_string get_data "select rwh_days_last_year from im_employees where employee_id = :user_id_from_search" -default 0]
if {![info exists rwh_days_last_year] || "" == $rwh_days_last_year} { set rwh_days_last_year 0 }

if {"" == $rwh_days_per_year} { set rwh_days_per_year 0 }

set rwh_days_left [expr $rwh_days_last_year + $rwh_days_per_year]
set rwh_days_taken 0

db_multirow -extend { absence_url absence_type } rwh_balance_multirow rwh_balance $vacation_sql {

    set absence_url [export_vars -base "$absence_base_url/new" {{form_mode display} absence_id}]
    set absence_type [im_category_from_id $absence_type_id]

    set rwh_days_taken [expr $rwh_days_taken + $duration_days]
    set rwh_days_left [expr $rwh_days_left - $duration_days]
}

ad_return_template

