-- upgrade-3.4.0.2.0-3.4.0.3.0.sql

CREATE OR REPLACE FUNCTION ad_group_member_p(integer, integer)
RETURNS character AS '
DECLARE
	p_user_id		alias for $1;
	p_group_id		alias for $2;

	ad_group_member_count	integer;
BEGIN
	select count(*)	into ad_group_member_count
	from	acs_rels r,
		membership_rels mr
	where
		r.rel_id = mr.rel_id
		and object_id_one = p_group_id
		and object_id_two = p_user_id
		and mr.member_state = ''approved''
	;

	if ad_group_member_count = 0 then
		return ''f'';
	else
		return ''t'';
	end if;
END;' LANGUAGE 'plpgsql';


-- Fix component packages
update im_component_plugins 
set package_name = 'intranet-core' 
where package_name = 'intranet';


-----------------------------------------------------
-- Create Project Hierarchy View

insert into im_views (view_id, view_name, visible_for, view_type_id)
values (25, 'project_hierarchy', 'view_projects', 1400);



--------------------------------------------------------------------------
-- Project Hierarchy

--
delete from im_view_columns where view_id = 25;
--
insert into im_view_columns (view_id, column_id, sort_order, column_name, column_render_tcl)
values (25,2510,10,'Empty','$arrow_right_html');

insert into im_view_columns (view_id, column_id, sort_order, column_name, column_render_tcl)
values (25,2520,20,'Nr','"$subproject_indent<a href=$subproject_url>$subproject_nr</a>"');

insert into im_view_columns (view_id, column_id, sort_order, column_name, column_render_tcl)
values (25,2530,30,'Name','"$subproject_indent<a href=$subproject_url>$subproject_name</a>"');

insert into im_view_columns (view_id, column_id, sort_order, column_name, column_render_tcl)
values (25,2540,40,'Status','$subproject_status');

insert into im_view_columns (view_id, column_id, sort_order, column_name, column_render_tcl)
values (25,2590,90,'Empty','$arrow_left_html');


