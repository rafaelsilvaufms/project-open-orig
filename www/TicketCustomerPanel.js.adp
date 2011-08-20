/**
 * intranet-sencha-ticket-tracker/www/TicketCustomerPanel.js
 * Shows the ticket's customer and allows to create a new customer.
 *
 * @author Frank Bergmann (frank.bergmann@project-open.com)
 * @creation-date 2011-05
 * @cvs-id $Id$
 *
 * Copyright (C) 2011, ]project-open[
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


Ext.define('TicketBrowser.TicketCustomerPanel', {
	extend:		'Ext.form.Panel',
	alias:		'widget.ticketCustomerPanel',
	id:		'ticketCustomerPanel',
	title:		'#intranet-sencha-ticket-tracker.Ticket_Customer#',
	frame:		true,
	fieldDefaults: {
		msgTarget:	'side',
		labelWidth:	125,
		typeAhead:	true				
	},
	items: [{
		name:		'company_id',
		xtype:		'combobox',
		fieldLabel:	'#intranet-sencha-ticket-tracker.CompanySearch#',
		valueNotFoundText: '#intranet-sencha-ticket-tracker.Create_New_Company#',
		value:		'#intranet-sencha-ticket-tracker.New_Customer#',
		valueField:	'company_id',
		displayField:   'company_name',
		store:		companyStore,
		queryMode:	'local',
		listeners: {

			// The user has selected a customer from the drop-down box.
			// Lookup the customer and fill the form with the fields.
			'blur': function() {
				var customer_id = this.getValue();
				var cust = companyStore.findRecord('company_id',customer_id);
				if (cust == null || cust == undefined) { 
					cust = companyStore.findRecord('company_name',customer_id);
				}
				if (cust == null || cust == undefined) { return; }

				// Add the province to the store (province field is now a combobox but data maybe no correct
				provincesStore.load();
				var company_province_name = cust.get('company_province');
				var store_company = provincesStore.findRecord('name',company_province_name,0,false,true,true);
				if (store_company==null){
					provincesStore.add({'name': company_province_name});
				}
				
				// load the record into the form
				this.ownerCt.loadRecord(cust);
			
				// Inform the TicketCustomerPanel about the new company
				var contactPanel = Ext.getCmp('ticketContactPanel');
				contactPanel.loadCustomer(cust);
			},
			change: function (field,newValue,oldValue) {
				 Ext.getCmp('ticketCompoundPanel').checkTicketField(field,newValue,oldValue)
			}
		}
	}, {
		name:		'company_name',
		xtype:		'textfield',
		fieldLabel:	'#intranet-sencha-ticket-tracker.Company_name#',
		allowBlank:	false
	}, {
		name:		'vat_number',
		xtype:		'textfield',
		fieldLabel:	'#intranet-sencha-ticket-tracker.VAT_Number#'
	},{
		name:		'company_type_id',
		xtype:		'combobox',
		fieldLabel:	'#intranet-sencha-ticket-tracker.Company_Type#',
		value:		'',
		valueField:	'category_id',
		displayField:   'category_translated',
		allowBlank:	false,
		store:		companyTypeStore,
		queryMode:	'local',
		listConfig: {
			getInnerTpl: function() {
                		return '<div class={indent_class}>{category_translated}</div>';
			}
		},
		validator: function(value){
			return this.store.validateLevel(this.value,this.allowBlank)
		}				
	}, 
	
	{
		name:		'company_province',
		xtype:		'combobox',
		fieldLabel:	'#intranet-sencha-ticket-tracker.Province#',
		allowBlank:	false,
		forceSelection: true,
		store: provincesStore,
		valueField:	'name',
		displayField:   'name',		
		queryMode: 'local'
	}],

	buttons: [{
		itemId:		'addButton',
		text: 		'#intranet-sencha-ticket-tracker.button_New_Company#',
		width: 		120,
		handler: function(){
			var form = this.ownerCt.ownerCt.getForm();
			form.reset();		// empty fields to allow for entry of new contact
	
			// Enable the button to save the new company
			var createButton = this.ownerCt.child('#createButton');
			createButton.show();
			
			// Disable the "Save Changes"  button
			var saveButton = this.ownerCt.child('#saveButton');
			saveButton.hide();
			
			// Diable this button
			this.hide();
		}
	}, {
		itemId:		'saveButton',
		text: 		'#intranet-sencha-ticket-tracker.Save_Changes#',
		width: 		120,
		formBind:	true,
		handler: function(){
			var form = this.ownerCt.ownerCt.getForm();
			var combo = form.findField('company_id');
			var values = form.getFieldValues();
			var company_id = combo.getValue();
							
			Function_checkValues(values);	
						
			// find the company in the store
			var company_record = companyStore.findRecord('company_id',company_id);
		/*	var company_name = form.findField('company_name').getValue();
			var vat_number = form.findField('vat_number').getValue();*/
			var company_name = values.company_name;
			var vat_number = values.vat_number;				
	
			if (company_id != anonimo_company_id) { //No save anonymous
				company_record.set('company_name', company_name.toUpperCase());
				company_record.set('vat_number', vat_number.toUpperCase());
				company_record.set('company_type_id', form.findField('company_type_id').getValue());
				company_record.set('company_province', form.findField('company_province').getValue());
	
				// Tell the store to update the server via it's REST proxy
				companyStore.sync();
			}
	
			// Write the new company (if any...) to the ticket store
			var ticket_form = Ext.getCmp('ticketForm');
			var ticket_id = ticket_form.getForm().findField('ticket_id').getValue();
			var ticketModel = ticketStore.findRecord('ticket_id',ticket_id);
			ticketModel.set('company_id', company_id);
	
			// Update the ticket model and tell the form to refresh everything
			ticketModel.save({
				scope: Ext.getCmp('ticketForm'),
				success: function(record, operation) {
					// Refresh all forms to show the updated information
					var compoundPanel = Ext.getCmp('ticketCompoundPanel');
					compoundPanel.loadTicket(ticketModel);
				},
				failure: function(record, operation) {
					Ext.Msg.alert("Failed to save ticket", operation.request.scope.reader.jsonData["message"]);
				}
			});
		}
	}, {
		itemId:		'createButton',
		text: 		'#intranet-sencha-ticket-tracker.Save_New_Company#',
		hidden:		true,			// only show when in "adding mode"
		formBind:	true,			
		handler: function(){
			var form = this.ownerCt.ownerCt.getForm();
			var values = form.getFieldValues();
	
			Function_checkValues(values);
		
			// create a new company
			values.company_id = null;
			var companyModel = Ext.ModelManager.create(values, 'TicketBrowser.Company');
			companyModel.phantom = true;
	
			// Only use upper case
			companyModel.set('company_name', values.company_name.toUpperCase());
			companyModel.set('vat_number', values.vat_number.toUpperCase());
	
			companyModel.save({
				success: function(company_record, operation) {
	
					// Store the new company in the store that that it can be referenced.
					companyStore.add(company_record);
	
					// Store the new company_id into the current ticket
					var ticketForm = Ext.getCmp('ticketForm');
					var ticket_id = ticketForm.getForm().findField('ticket_id').getValue();
					var ticket_model = ticketStore.findRecord('ticket_id',ticket_id);
					var company_id = company_record.get('company_id');
					ticket_model.set('company_id', company_id);
					ticket_model.save({
						success: function(record, operation) {
							// Tell all panels to load the data of the newly created object
							var compoundPanel = Ext.getCmp('ticketCompoundPanel');
							compoundPanel.loadTicket(ticket_model);	
						},
						failure: function(record, operation) { 
							Ext.Msg.alert("Failed to save ticket", operation.request.scope.reader.jsonData["message"]);
						}
					});
				},
				failure: function(user_record, operation) {
					Ext.Msg.alert("Error durante la creacion de una nueva entidad", operation.request.scope.reader.jsonData["message"]);
				}
	
			});
		}
	}],


	// For a new ticket reset the values of the form.
	newTicket: function() {
		var form = this.getForm();
		form.reset();

		provincesStore.load();
		
		// Don't show this form for new tickets
		this.hide();
	},

	loadTicket: function(rec){

		this.getForm().reset();
		// Show the form
		this.show();		

		// Customer ID, may be NULL
		var customer_id;
		if (rec.data.hasOwnProperty('company_id')) { customer_id = rec.data.company_id; }

		companyStore.clearFilter();
		var cust = companyStore.findRecord('company_id',customer_id);
		if (cust == null || typeof cust == "undefined") { return; }

		// Add the province to the store (province field is now a combobox but data maybe no correct
		provincesStore.load();
		var company_province_name = cust.get('company_province');
		var store_company = provincesStore.findRecord('name',company_province_name,0,false,true,true);
		if (store_company==null){
			provincesStore.add({'name': company_province_name});
		}
		
		// load the customer's information into the form.
		this.loadRecord(cust);

		// Reset button config
		var buttonToolbar = this.getDockedComponent(0);
		var addButton = buttonToolbar.getComponent('addButton');
		
		if (Ext.isEmpty(addButton)) {
			var buttonToolbar = this.getDockedComponent(1);
			var addButton = buttonToolbar.getComponent('addButton');			
		}
		addButton.show();
		var saveButton = buttonToolbar.getComponent('saveButton');
		saveButton.show();
		
		var createButton = buttonToolbar.getComponent('createButton');
		createButton.hide();

		//Disable de buttons if the ticket is closed
		var ticket_status_id=rec.get('ticket_status_id');
		if (ticket_status_id == '30001' && currentUserIsAdmin != 1){
			buttonToolbar.disable();
		}	else {
			buttonToolbar.enable();
		}				
	}

});

