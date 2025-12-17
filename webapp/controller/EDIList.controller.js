sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (Controller, JSONModel, Filter, FilterOperator, MessageToast, MessageBox) {
    "use strict";

    return Controller.extend("edi.monitor.controller.EDIList", {

        onInit: function () {
            // Initialize view model
            const oViewModel = new JSONModel({
                severityFilter: ""
            });
            this.getView().setModel(oViewModel, "view");

            // Initialize EDI data model
            const oEDIModel = new JSONModel({
                data: [],
                count: 0,
                loading: false
            });
            this.getView().setModel(oEDIModel, "edi");

            // Load EDI data
            this._loadEDIData();
        },

        /**
         * Load EDI data from API
         * @private
         */
        _loadEDIData: function (sSeverity) {
            const oModel = this.getView().getModel("edi");
            oModel.setProperty("/loading", true);

            const sApiEndpoint = this._getAPIEndpoint();
            let sUrl = sApiEndpoint + "/api/edi-data";

            // Add severity filter if provided
            if (sSeverity) {
                sUrl += "?severity=" + sSeverity;
            }

            fetch(sUrl)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.json();
                })
                .then(data => {
                    oModel.setData(data);
                    oModel.setProperty("/loading", false);
                })
                .catch(error => {
                    console.error("Error loading EDI data:", error);
                    MessageBox.error("Failed to load EDI data: " + error.message);
                    oModel.setProperty("/loading", false);
                });
        },

        /**
         * Get API endpoint from configuration
         * @private
         */
        _getAPIEndpoint: function () {
            const oConfigModel = this.getOwnerComponent().getModel("config");
            return oConfigModel.getProperty("/apiEndpoint");
        },

        /**
         * Handle search
         */
        onSearch: function (oEvent) {
            const sQuery = oEvent.getParameter("query");
            const oTable = this.byId("ediTable");
            const oBinding = oTable.getBinding("items");

            if (!oBinding) {
                return;
            }

            const aFilters = [];
            if (sQuery) {
                aFilters.push(new Filter({
                    filters: [
                        new Filter("document_number", FilterOperator.Contains, sQuery),
                        new Filter("store_name", FilterOperator.Contains, sQuery),
                        new Filter("vendor_name", FilterOperator.Contains, sQuery)
                    ],
                    and: false
                }));
            }

            oBinding.filter(aFilters);
        },

        /**
         * Handle filter change
         */
        onFilterChange: function (oEvent) {
            const sKey = oEvent.getParameter("item").getKey();
            this.getView().getModel("view").setProperty("/severityFilter", sKey);
            this._loadEDIData(sKey);
        },

        /**
         * Handle document selection
         */
        onDocumentSelect: function (oEvent) {
            const oItem = oEvent.getParameter("listItem");
            const oContext = oItem.getBindingContext("edi");
            const sDocumentNumber = oContext.getProperty("document_number");

            this.getOwnerComponent().getRouter().navTo("ediDetail", {
                documentNumber: sDocumentNumber
            });
        },

        /**
         * Handle table update finished
         */
        onUpdateFinished: function (oEvent) {
            const iTotal = oEvent.getParameter("total");
            const oModel = this.getView().getModel("edi");
            oModel.setProperty("/count", iTotal);
        },

        /**
         * Navigate back
         */
        onNavBack: function () {
            this.getOwnerComponent().getRouter().navTo("dashboard");
        },

        /**
         * Refresh data
         */
        onRefresh: function () {
            MessageToast.show(this.getView().getModel("i18n").getResourceBundle().getText("refreshing"));
            const sSeverity = this.getView().getModel("view").getProperty("/severityFilter");
            this._loadEDIData(sSeverity);
        },

        /**
         * Export to Excel
         */
        onExport: function () {
            MessageToast.show("Export functionality - to be implemented");
        }
    });
});
