--
-- /packages/acs-kernel/sql/upgrade/upgrade-4.0-4.0.1.sql
-- 
-- Upgrades ACS 4.0 to ACS 4.0.1
--
-- @author Multiple
-- @creation-date Wed Nov  1 10:32:08 2000
-- @cvs-id $Id: upgrade-4.0-4.0.1.sql,v 1.2 2010/10/19 20:11:36 po34demo Exp $

-- upgrade security.

create or replace package sec
as

    function allocate_sessions(
        v_preallocated_server in varchar2,
	v_sessions_to_allocate in integer
	)
    return varchar2;
end sec;
/
show errors

create or replace package body sec
as

    -- Insert a bunch of rows into sec_sessions with a given preallocated_server.
    function allocate_sessions(
	v_preallocated_server in varchar2,
	v_sessions_to_allocate in integer
    )
    return varchar2
    is
	-- Define table types for bulk inserts.
	type int_tab is table of integer index by binary_integer;
    
	a_session_ids int_tab;
	a_session_id_string varchar2(4000);
    
	a_count integer := 1;
        pragma autonomous_transaction;
    begin
	while a_count <= v_sessions_to_allocate loop
	    select sec_id_seq.nextval into a_session_ids(a_session_ids.count + 1) from dual;
	    a_session_id_string := a_session_id_string || ',' || a_session_ids(a_session_ids.count);
	    a_count := a_count + 1;
	end loop;
    
	forall i in 1..a_session_ids.count
	    insert into sec_sessions(session_id, preallocated_server)
	    values(a_session_ids(i), v_preallocated_server);

	commit;

	-- strip initial comma
	return substr(a_session_id_string, 2);
    end;    
end sec;
/
show errors

drop table sec_browser_properties;
drop table sec_login_tokens;

alter table sec_sessions drop column token;
alter table sec_sessions drop column secure_token;
alter table sec_sessions drop column browser_id;
alter table sec_sessions add (first_hit integer);
update sec_sessions set first_hit = last_hit where last_hit is not null;
alter table sec_sessions drop column last_hit;

alter sequence sec_security_token_id_seq cache 100;
alter sequence sec_id_seq cache 1000;

create index sec_property_names on sec_session_properties(property_name);

-- upgrade parties

update parties set email = lower(email);

-- performance improvements

-- create bitmap index acs_obj_types_supertype_idx on acs_object_types (supertype);
create index acs_obj_types_supertype_idx on acs_object_types (supertype);

-- update apm procedures
-- bquinn@arsdigita.com 11/18/2000

declare
    none_null_p integer;
    cursor all_pretty_names is
    	select pretty_name from apm_package_types;
begin
    none_null_p := 1;
    for cur_val in all_pretty_names
    loop
    	if cur_val.pretty_name is not null then
	    none_null_p := 0;
	end if;
    end loop;
    if none_null_p = 1 then
    execute immediate 'alter table apm_package_types modify (pretty_name varchar2(100) not null)';
    end if;	
end;
/
show errors

create or replace package body apm
as
  procedure register_package (
    package_key			in apm_package_types.package_key%TYPE,
    pretty_name			in apm_package_types.pretty_name%TYPE,
    pretty_plural		in apm_package_types.pretty_plural%TYPE,
    package_uri			in apm_package_types.package_uri%TYPE,
    package_type		in apm_package_types.package_type%TYPE,
    singleton_p			in apm_package_types.singleton_p%TYPE 
				default 'f',    
    spec_file_path		in apm_package_types.spec_file_path%TYPE 
				default null,
    spec_file_mtime		in apm_package_types.spec_file_mtime%TYPE 
				default null
  ) 
  is
  begin
    apm_package_type.create_type(
    	package_key => register_package.package_key,
	pretty_name => register_package.pretty_name,
	pretty_plural => register_package.pretty_plural,
	package_uri => register_package.package_uri,
	package_type => register_package.package_type,
	singleton_p => register_package.singleton_p,
	spec_file_path => register_package.spec_file_path,
	spec_file_mtime => spec_file_mtime
    );
  end register_package;

  function update_package (
    package_key			in apm_package_types.package_key%TYPE,
    pretty_name			in apm_package_types.pretty_name%TYPE
    	    	    	    	default null,
    pretty_plural		in apm_package_types.pretty_plural%TYPE
    	    	    	    	default null,
    package_uri			in apm_package_types.package_uri%TYPE
    	    	    	    	default null,
    package_type		in apm_package_types.package_type%TYPE
    	    	    	    	default null,
    singleton_p			in apm_package_types.singleton_p%TYPE 
    	    	    	    	default null,    
    spec_file_path		in apm_package_types.spec_file_path%TYPE 
    	    	    	    	default null,
    spec_file_mtime		in apm_package_types.spec_file_mtime%TYPE 
				default null
  ) return apm_package_types.package_type%TYPE
  is
  begin
 
    return apm_package_type.update_type(
    	package_key => update_package.package_key,
	pretty_name => update_package.pretty_name,
	pretty_plural => update_package.pretty_plural,
	package_uri => update_package.package_uri,
	package_type => update_package.package_type,
	singleton_p => update_package.singleton_p,
	spec_file_path => update_package.spec_file_path,
	spec_file_mtime => update_package.spec_file_mtime
    );

  end update_package;    


 procedure unregister_package (
    package_key		in apm_package_types.package_key%TYPE,
    cascade_p		in char default 't'
  )
  is
  begin
   apm_package_type.drop_type(
	package_key => unregister_package.package_key,
	cascade_p => unregister_package.cascade_p
   );
  end unregister_package;

  function register_p (
    package_key		in apm_package_types.package_key%TYPE
  ) return integer
  is
    v_register_p integer;
  begin
    select decode(count(*),0,0,1) into v_register_p from apm_package_types 
    where package_key = register_p.package_key;
    return v_register_p;
  end register_p;

  procedure register_application (
    package_key			in apm_package_types.package_key%TYPE,
    pretty_name			in apm_package_types.pretty_name%TYPE,
    pretty_plural		in apm_package_types.pretty_plural%TYPE,
    package_uri			in apm_package_types.package_uri%TYPE,
    singleton_p			in apm_package_types.singleton_p%TYPE 
				default 'f',    
    spec_file_path		in apm_package_types.spec_file_path%TYPE 
				default null,
    spec_file_mtime		in apm_package_types.spec_file_mtime%TYPE 
				default null
  ) 
  is
  begin
    apm.register_package(
	package_key => register_application.package_key,
	pretty_name => register_application.pretty_name,
	pretty_plural => register_application.pretty_plural,
	package_uri => register_application.package_uri,
	package_type => 'apm_application',
	singleton_p => register_application.singleton_p,
	spec_file_path => register_application.spec_file_path,
	spec_file_mtime => register_application.spec_file_mtime
   ); 
  end register_application;  

  procedure unregister_application (
    package_key		in apm_package_types.package_key%TYPE,
    cascade_p		in char default 'f'
  )
  is
  begin
   apm.unregister_package (
	package_key => unregister_application.package_key,
	cascade_p => unregister_application.cascade_p
   );
  end unregister_application; 

  procedure register_service (
    package_key			in apm_package_types.package_key%TYPE,
    pretty_name			in apm_package_types.pretty_name%TYPE,
    pretty_plural		in apm_package_types.pretty_plural%TYPE,
    package_uri			in apm_package_types.package_uri%TYPE,
    singleton_p			in apm_package_types.singleton_p%TYPE 
				default 'f',    
    spec_file_path		in apm_package_types.spec_file_path%TYPE 
				default null,
    spec_file_mtime		in apm_package_types.spec_file_mtime%TYPE 
				default null
  ) 
  is
  begin
   apm.register_package(
	package_key => register_service.package_key,
	pretty_name => register_service.pretty_name,
	pretty_plural => register_service.pretty_plural,
	package_uri => register_service.package_uri,
	package_type => 'apm_service',
	singleton_p => register_service.singleton_p,
	spec_file_path => register_service.spec_file_path,
	spec_file_mtime => register_service.spec_file_mtime
   );   
  end register_service;

  procedure unregister_service (
    package_key		in apm_package_types.package_key%TYPE,
    cascade_p		in char default 'f'
  )
  is
  begin
   apm.unregister_package (
	package_key => unregister_service.package_key,
	cascade_p => unregister_service.cascade_p
   );
  end unregister_service;

  -- Indicate to APM that a parameter is available to the system.
  function register_parameter (
    parameter_id		in apm_parameters.parameter_id%TYPE 
				default null,
    package_key			in apm_parameters.package_key%TYPE,				
    parameter_name		in apm_parameters.parameter_name%TYPE,
    description			in apm_parameters.description%TYPE
				default null,
    datatype			in apm_parameters.datatype%TYPE 
				default 'string',
    default_value		in apm_parameters.default_value%TYPE 
				default null,
    section_name		in apm_parameters.section_name%TYPE
				default null,
    min_n_values		in apm_parameters.min_n_values%TYPE 
				default 1,
    max_n_values		in apm_parameters.max_n_values%TYPE 
				default 1
  ) return apm_parameters.parameter_id%TYPE
  is
    v_parameter_id apm_parameters.parameter_id%TYPE;
    cursor all_parameters is
       select ap.package_id, p.parameter_id, p.default_value 
       from apm_parameters p, apm_parameter_values v, apm_packages ap
       where p.package_key = ap.package_key
       and p.parameter_id = v.parameter_id (+)
       and v.attr_value is null
       and p.package_key = register_parameter.package_key;       
  begin
    -- Create the new parameter.    
    v_parameter_id := acs_object.new(
       object_id => parameter_id,
       object_type => 'apm_parameter'
    );
    
    insert into apm_parameters 
    (parameter_id, parameter_name, description, package_key, datatype, 
    default_value, section_name, min_n_values, max_n_values)
    values
    (v_parameter_id, register_parameter.parameter_name, register_parameter.description,
    register_parameter.package_key, register_parameter.datatype, 
    register_parameter.default_value, register_parameter.section_name, 
	register_parameter.min_n_values, register_parameter.max_n_values);
    -- Propagate parameter to new instances.	
    for cur_val in all_parameters
      loop
      	apm.set_value(
	    package_id => cur_val.package_id,
	    parameter_id => cur_val.parameter_id, 
	    attr_value => cur_val.default_value
	    ); 	
      end loop;		
    return v_parameter_id;
  end register_parameter;

    function update_parameter (
    parameter_id		in apm_parameters.parameter_id%TYPE,
    parameter_name		in apm_parameters.parameter_name%TYPE
    	    	    	    	default null,
    description			in apm_parameters.description%TYPE
				default null,
    datatype			in apm_parameters.datatype%TYPE 
				default 'string',
    default_value		in apm_parameters.default_value%TYPE 
				default null,
    section_name		in apm_parameters.section_name%TYPE
				default null,
    min_n_values		in apm_parameters.min_n_values%TYPE 
				default 1,
    max_n_values		in apm_parameters.max_n_values%TYPE 
				default 1
  ) return apm_parameters.parameter_name%TYPE
  is
  begin
    update apm_parameters 
	set parameter_name = nvl(update_parameter.parameter_name, parameter_name),
            default_value  = nvl(update_parameter.default_value, default_value),
            datatype       = nvl(update_parameter.datatype, datatype), 
	    description	   = nvl(update_parameter.description, description),
	    section_name   = nvl(update_parameter.section_name, section_name),
            min_n_values   = nvl(update_parameter.min_n_values, min_n_values),
            max_n_values   = nvl(update_parameter.max_n_values, max_n_values)
      where parameter_id = update_parameter.parameter_id;
    return parameter_id;
  end;

  function parameter_p(
    package_key                 in apm_package_types.package_key%TYPE,
    parameter_name              in apm_parameters.parameter_name%TYPE
  ) return integer 
  is
    v_parameter_p integer;
  begin
    select decode(count(*),0,0,1) into v_parameter_p 
    from apm_parameters
    where package_key = parameter_p.package_key
    and parameter_name = parameter_p.parameter_name;
    return v_parameter_p;
  end parameter_p;

  procedure unregister_parameter (
    parameter_id		in apm_parameters.parameter_id%TYPE 
				default null
  )
  is
  begin
    delete from apm_parameter_values 
    where parameter_id = unregister_parameter.parameter_id;
    delete from apm_parameters 
    where parameter_id = unregister_parameter.parameter_id;
    acs_object.delete(parameter_id);
  end unregister_parameter;

  function id_for_name (
    parameter_name		in apm_parameters.parameter_name%TYPE,
    package_key			in apm_parameters.package_key%TYPE
  ) return apm_parameters.parameter_id%TYPE
  is
    a_parameter_id apm_parameters.parameter_id%TYPE; 
  begin
    select parameter_id into a_parameter_id
    from apm_parameters p
    where p.parameter_name = id_for_name.parameter_name and
          p.package_key = id_for_name.package_key;
    return a_parameter_id;
  end id_for_name;
		
  function get_value (
    parameter_id		in apm_parameter_values.parameter_id%TYPE,
    package_id			in apm_packages.package_id%TYPE		    
  ) return apm_parameter_values.attr_value%TYPE
  is
    value apm_parameter_values.attr_value%TYPE;
  begin
    select attr_value into value from apm_parameter_values v
    where v.package_id = get_value.package_id
    and parameter_id = get_value.parameter_id;
    return value;
  end get_value;

  function get_value (
    package_id			in apm_packages.package_id%TYPE,
    parameter_name		in apm_parameters.parameter_name%TYPE
  ) return apm_parameter_values.attr_value%TYPE
  is
    v_parameter_id apm_parameter_values.parameter_id%TYPE;
  begin
    select parameter_id into v_parameter_id 
    from apm_parameters 
    where parameter_name = get_value.parameter_name
    and package_key = (select package_key  from apm_packages
			where package_id = get_value.package_id);
    return apm.get_value(
	parameter_id => v_parameter_id,
	package_id => get_value.package_id
    );	
  end get_value;	


  -- Sets a value for a parameter for a package instance.
  procedure set_value (
    parameter_id		in apm_parameter_values.parameter_id%TYPE,
    package_id			in apm_packages.package_id%TYPE,	    
    attr_value			in apm_parameter_values.attr_value%TYPE
  ) 
  is
    v_value_id apm_parameter_values.value_id%TYPE;
  begin
    -- Determine if the value exists
    select value_id into v_value_id from apm_parameter_values 
     where parameter_id = set_value.parameter_id 
     and package_id = set_value.package_id;
    update apm_parameter_values set attr_value = set_value.attr_value
     where parameter_id = set_value.parameter_id 
     and package_id = set_value.package_id;    
     exception 
       when NO_DATA_FOUND
       then
         v_value_id := apm_parameter_value.new(
            package_id => set_value.package_id,
            parameter_id => set_value.parameter_id,
            attr_value => set_value.attr_value
         );
   end set_value;

  procedure set_value (
    package_id			in apm_packages.package_id%TYPE,
    parameter_name		in apm_parameters.parameter_name%TYPE,
    attr_value			in apm_parameter_values.attr_value%TYPE
  ) 
  is
    v_parameter_id apm_parameter_values.parameter_id%TYPE;
  begin
    select parameter_id into v_parameter_id 
    from apm_parameters 
    where parameter_name = set_value.parameter_name
    and package_key = (select package_key  from apm_packages
			where package_id = set_value.package_id);
    apm.set_value(
	parameter_id => v_parameter_id,
	package_id => set_value.package_id,
	attr_value => set_value.attr_value
    );
    exception
      when NO_DATA_FOUND
      then
      	RAISE_APPLICATION_ERROR(-20000, 'The specified package ' || set_value.package_id || 
	' does not exist in the system.');	
  end set_value;	
end apm;
/
show errors  

declare
    file_type_p integer;
begin
    select decode(count(*), 0, 0, 1) into file_type_p from apm_package_file_types
     	where file_type_key = 'sqlj_code';
    if file_type_p != 1 then
	insert into apm_package_file_types(file_type_key, pretty_name) values('sqlj_code', 'SQLJ Library');
	commit;
    end if;    
end;
/
show errors
