sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/m/MessageToast",
    "sap/m/MessageBox"
], function (Controller, JSONModel, MessageToast, MessageBox) {
    "use strict";

    return Controller.extend("edi.monitor.controller.Dashboard", {

        onInit: function () {
            // Initialize dashboard model
            const oDashboardModel = new JSONModel({
                total_documents: 0,
                error_documents: 0,
                warning_documents: 0,
                success_documents: 0,
                error_rate: 0,
                recent_errors: [],
                loading: false
            });
            this.getView().setModel(oDashboardModel, "dashboard");

            // Load dashboard data
            this._loadDashboardData();
        },

        /**
         * Load dashboard data from API
         * @private
         */
        _loadDashboardData: function () {
            const oModel = this.getView().getModel("dashboard");
            oModel.setProperty("/loading", true);

            const sApiEndpoint = this._getAPIEndpoint();
            const sUrl = sApiEndpoint + "/api/dashboard";

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
                    console.error("Error loading dashboard data:", error);
                    MessageBox.error("Failed to load dashboard data: " + error.message);
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
         * Navigate to EDI list view
         */
        onNavigateToList: function () {
            this.getOwnerComponent().getRouter().navTo("ediList");
        },

        /**
         * Show only error documents
         */
        onShowErrors: function () {
            this.getOwnerComponent().getRouter().navTo("ediList", {
                severity: "Error"
            });
        },

        /**
         * Show only warning documents
         */
        onShowWarnings: function () {
            this.getOwnerComponent().getRouter().navTo("ediList", {
                severity: "Warning"
            });
        },

        /**
         * Show only success documents
         */
        onShowSuccess: function () {
            this.getOwnerComponent().getRouter().navTo("ediList", {
                severity: "Success"
            });
        },

        /**
         * Handle error selection from table
         */
        onErrorSelect: function (oEvent) {
            const oItem = oEvent.getParameter("listItem");
            const oContext = oItem.getBindingContext("dashboard");
            const sDocumentNumber = oContext.getProperty("document_number");

            this.getOwnerComponent().getRouter().navTo("ediDetail", {
                documentNumber: sDocumentNumber
            });
        },

        /**
         * Refresh dashboard data
         */
        onRefresh: function () {
            MessageToast.show(this.getView().getModel("i18n").getResourceBundle().getText("refreshing"));
            this._loadDashboardData();
        }
    });
});
