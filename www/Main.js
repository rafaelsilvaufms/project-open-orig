/**
 * intranet-sencha-ticket-tracker/www/Main.js
 * Main page for the ]po[ Sencha Ticket Browser.
 *
 * @author Frank Bergmann (frank.bergmann@project-open.com)
 * @creation-date 2011-05
 * @cvs-id $Id: Main.js,v 1.6 2011/05/30 16:12:24 mcordova Exp $
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

Ext.define('TicketBrowser.Main', {
    extend: 'Ext.container.Viewport',

    initComponent: function(){
        Ext.apply(this, {
            layout: 'border',
            itemId: 'main',
            items: [{
                xtype: 'ticketfilteraccordion',
                region: 'west',
                width: 300,
                title: 'Ticket Filters',
                split: true,
                margins: '5 0 5 5'
            }, {
                region: 'center',
                xtype: 'tabpanel',
                margins: '5 5 5 0',
                minWidth: 400,
                border: false,
                tabBar: {
                    border: true
                },
                items: {
                    itemId: 'ticket',
                    xtype: 'ticketcontainer'
                }
            }]
        });
        this.callParent();
    },

    loadSla: function(rec){
        this.down('#ticket').loadSla(rec);
    },

    filterTickets: function(filterValues){
        this.down('#ticket').filterTickets(filterValues);
    }
});
