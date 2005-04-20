ad_page_contract {
    Loads a package from a URL into the package manager.

    @param url The url of the package to load.
    @author Bryan Quinn (bquinn@arsdigita.com)
    @creation-date 10 October 2000
    @cvs-id $Id$

} {
    url
    email
    password

    { orderby "package_key" }
    { owned_by "everyone" }
    { supertype "all" }
    { reload_links_p 0 }
}

# ------------------------------------------------------------
# Authentication & defaults
#

set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_need_to_be_a_syst]">
    return
}

set return_url "[ad_conn url]?[ad_conn query]"
set page_title "Automatic Software Updates"
set context_bar [im_context_bar $page_title]
set context [list [list "../developer" "Developer's Administration"] $page_title]

set bgcolor(0) " class=roweven"
set bgcolor(1) " class=rowodd"

set email "fraber@fraber.de"
set password "fraber"

set full_url "$url?email=[ns_urlencode $email]&password=[ns_urlencode $password]"

ns_log Notice "load-update-xml-2: full_url=$full_url"
ns_log Notice "load-update-xml-2: email=$email"

set update_xml ""


# ------------------------------------------------------------
# Fetch the update.xml file from the remote server
#

if { [catch {

    ns_log Notice "load-update-xml-2: Opening $full_url"
    set httpChan [lindex [ns_httpopen GET $full_url] 0]
    ns_log Notice "load-update-xml-2: httpChan=$httpChan"

    while {[gets $httpChan update_line] >= 0} {
	append update_xml $update_line
    }

    ns_log Debug "load-update-xml-2: Done copying data."
    close $httpChan

} errmsg] } {
    ad_return_complaint 1 "Unable to download. Please check your URL.</ul>.
	The following error was returned: <blockquote><pre>[ad_quotehtml $errmsg]
	</pre></blockquote>[ad_footer]"
    return
}	


# ------------------------------------------------------------
# Parse the XML file and generate the HTML table
#

# Sample record:
#
#  <version name="3.0.beta7">
#    <package>All</package>
#    <whats_new>Improved installer</whats_new>
#    <cvs_server>berlin.dnsalias.com</cvs_server>
#    <cvs_command>update -r v3-0-beta7</cvs_command>
#    <update_urgency format="text/plain">Optional Upgrade</update_urgency>
#  </version>

set tree [xml_parse -persist $update_xml]
set root_node [xml_doc_get_first_node $tree]

set root_name [xml_node_get_name $root_node]
if { ![string equal $root_name "update_info"] } {
    error "Expected <update_info> as root node of update.xml file, found: 'root_name'"
}

set ctr 0
set debug ""
set version_list [list]
set version_nodes [xml_node_get_children $root_node]
set version_html ""
foreach version_node $version_nodes {

    set version_node_name [xml_node_get_name $version_node]
    if { ![string equal $version_node_name "version"] } {
	error "Expected <version> under the root node of update.xml file, found: '$version_node_name'"
    }
    set version_name [apm_required_attribute_value $version_node name]
    set version_url [apm_tag_value $version_node version_url]
    set package [apm_tag_value -default "" $version_node package]
    set package_url [apm_tag_value -default "" $version_node package_url]
    set release_date [apm_tag_value -default "" $version_node release_date]
    set whats_new [apm_tag_value -default "" $version_node whats_new]
    set cvs_action [apm_tag_value -default "" $version_node cvs_action]
    set cvs_server [apm_tag_value -default "" $version_node cvs_server]
    set cvs_root [apm_tag_value -default "" $version_node cvs_root]
    set cvs_command [apm_tag_value -default "" $version_node cvs_command]
    set update_urgency [apm_tag_value -default "" $version_node update_urgency]
    set forum_url [apm_tag_value -default "" $version_node forum_url]
    set forum_title [apm_tag_value -default "" $version_node forum_title]
    set update_url [export_vars -base cvs-update {cvs_server cvs_command cvs_root}]

    set package_formatted $package
    if {"" != $package_url} {set package_formatted "<a href=\"$package_url\">$package</a>" }

    set version_formatted $version_name
    if {"" != $version_url} {set version_formatted "<a href=\"$version_url\">$version_name</a>" }

    append version_html "
<tr $bgcolor([expr $ctr % 2])>
  <td><a href=\"$update_url\" title=\"Update\" class=\"button\">$cvs_action</a>&nbsp;</td>
  <td>$version_formatted</td>
  <td>$release_date</td>
  <td>$package_formatted</td>
  <td><a href=\"$forum_url\">$forum_title</a></td>
  <td>$update_urgency</td>
  <td>$whats_new</td>
</tr>
"

    incr ctr
}


# ------------------------------------------------------------
# Show the list of currently installed packages
#

set dimensional_list {
    {
        supertype "Package Type:" all {
	    { apm_application "Applications" { where "[db_map apm_application]" } }
	    { apm_service "Services" { where "t.package_type = 'apm_service'"} }
	    { all "All" {} }
	}
    }
    {

	owned_by "Owned by:" everyone {
	    { me "Me" {where "[db_map everyone]"} }
	    { everyone "Everyone" {where "1 = 1"} }
	}
    }
    {
	status "Status:" latest {
	    {
		latest "Latest" {where "[db_map latest]" }
	    }
	    { all "All" {where "1 = 1"} }
	}
    }
}

set missing_text "<strong>No packages match criteria.</strong>"

# append body "<center><table><tr><td>[ad_dimensional $dimensional_list]</td></tr></table></center>"

set use_watches_p [expr ! [ad_parameter -package_id [ad_acs_kernel_id] PerformanceModeP request-processor 1]]

set table_def {
    { package_key "Key" "" "<td><a href=\"[export_vars -base /acs-admin/apm/version-view { version_id }]\">$package_key</a></td>" }
    { pretty_name "Name" "" "<td><a href=\"[export_vars -base /acs-admin/apm/version-view { version_id }]\">$pretty_name</a></td>" }
    { version_name "Ver." "" "" }
    {
	status "Status" "" {<td align=center>&nbsp;&nbsp;[eval {
	    if { $installed_p == "t" } {
		if { $enabled_p == "t" } {
		    set status "Enabled"
		} else {
		    set status "Disabled"
		}
	    } elseif { $superseded_p } {
		set status "Superseded"
	    } else {
		set status "Uninstalled"
	    }
	    format $status
	}]&nbsp;&nbsp;</td>}
    }
}

doc_body_flush

set table [ad_table -Torderby $orderby -Tmissing_text $missing_text "apm_table" "" $table_def]

db_release_unused_handles

# The reload links make the page slow, so make them optional
set page_url "[ad_conn url]?[export_vars -url {orderby owned_by supertype}]"
if { $reload_links_p } {
    set reload_filter "<a href=\"$page_url&reload_links_p=0\">Do not check for changed files</a>"
} else {
    set reload_filter "<a href=\"$page_url&reload_links_p=1\">Check for changed files</a>"
}

