-------------------------------------------------------------
-- upgrade-3.2.0.0.0-3.2.1.0.0.sql
-------------------------------------------------------------




-------------------------------------------------------------
-- Extend im_categories with "aux" fields

alter table im_categories add
aux_int1 integer;

alter table im_categories add
aux_int2 integer;

alter table im_categories add
aux_string1 varchar(1000);

alter table im_categories add
aux_string2 varchar(1000);

update im_categories
set aux_string1 = category_description;



-- -----------------------------------------------------
-- Add a customer_project_nr if not already there...


create or replace function inline_0 ()
returns integer as '
declare
        v_count                 integer;
begin
        select  count(*)
        into    v_count
        from    user_tab_columns
        where   lower(table_name) = ''im_projects''
		and lower(column_name) = ''company_project_nr'';

        if v_count = 1 then
            return 0;
        end if;

        alter table im_projects
        add company_project_nr varchar(200);

        return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



create or replace function inline_0 ()
returns integer as '
declare
        v_count                 integer;
begin
        select  count(*)
        into    v_count
        from    user_tab_columns
        where   lower(table_name) = ''im_projects''
		and lower(column_name) = ''final_company'';

        if v_count = 1 then
            return 0;
        end if;

        alter table im_projects
        add final_company varchar(200);

        return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




