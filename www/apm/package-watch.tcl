ad_page_contract {
    Schedules all -procs.tcl and xql files of a package to be watched.


    @author Peter Marklund
    @cvs-id $Id$
} {
    package_key
    {return_url "index"}
} 

apm_watch_all_files $package_key

ad_returnredirect $return_url
