<master src="../../intranet-core/www/master">
<property name="title">@page_title;noquote@</property>
<property name="main_navbar_label">finance</property>

<%= [im_costs_navbar "none" "/intranet/invoices/index" "" "" [list]] %>

<form method=POST action=invoice-association-action-2.tcl>
<%= [export_form_vars invoice_id return_url] %>
<table border=0 cellspacing=1 cellpadding=1>
  <tr>
    <td>
      Invoice Nr:
    </td>
    <td>
      @invoice_nr@
    </td>
  </tr>
  <tr>
    <td>
      Company.
    </td>
    <td>
      <A href="/intranet/companies/view?company_id=@company_id@">@company_name@</A>
    </td>
  </tr>
  <tr>
    <td>
      Associte with:
    </td>
    <td>
      @project_select;noquote@
    </td>
  </tr>
  <tr>
    <td colspan=2 align=right>
      <input type=submit value="Assoiate">
    </td>
  </tr>
</table>
</form>
