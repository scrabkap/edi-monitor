sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel"
], function (Controller, JSONModel) {
    "use strict";

    return Controller.extend("edi.monitor.controller.Dashboard", {

        onInit: function () {
            // Initialize dashboard model
            const oDashboardModel = new JSONModel({
                total_documents: 0,
                error_documents: 0,
                warning_documents: 0,
                success_documents: 0,
                total_items: 0,
                error_items: 0
            });
            this.getView().setModel(oDashboardModel, "dashboard");

            // Load dashboard data from SAP OData
            this._loadDashboardData();
        },

        /**
         * Load dashboard KPIs from SAP OData service
         * @private
         */
        _loadDashboardData: function () {
            const oModel = this.getView().getModel(); // OData V4 model
            const oViewModel = this.getView().getModel("view");

            // Set busy indicator
            oViewModel.setProperty("/busy", true);

            // ========================================================================
            // ODATA V4: Bind to DashboardKPI entity
            // ========================================================================
            // URL: /DashboardKPI('MAIN')
            const oBinding = oModel.bindContext("/DashboardKPI('MAIN')");

            oBinding.requestObject().then((oData) => {
                // Success - update dashboard model
                const oDashboardModel = this.getView().getModel("dashboard");
                oDashboardModel.setData({
                    total_documents: oData.TotalDocuments || 0,
                    error_documents: oData.ErrorDocuments || 0,
                    warning_documents: oData.WarningDocuments || 0,
                    success_documents: oData.SuccessDocuments || 0,
                    total_items: oData.TotalItems || 0,
                    error_items: oData.ErrorItems || 0
                });

                oViewModel.setProperty("/busy", false);

            }).catch((oError) => {
                // Error handling
                console.error("Error loading dashboard data:", oError);
                oViewModel.setProperty("/busy", false);

                sap.m.MessageBox.error(
                    "Failed to load dashboard data. Please check your connection to the SAP system.",
                    {
                        title: "Error",
                        details: oError.message
                    }
                );
            });
        },

        /**
         * Navigate to EDI List filtered by severity
         * @param {string} sSeverity - Severity filter (Error, Warning, Success)
         * @private
         */
        _navigateToList: function (sSeverity) {
            this.getOwnerComponent().getRouter().navTo("ediList", {
                severity: sSeverity
            });
        },

        /**
         * Show all documents (no filter)
         */
        onShowAll: function () {
            this.getOwnerComponent().getRouter().navTo("ediList", {
                severity: ""
            });
        },

        /**
         * Show only documents with errors
         */
        onShowErrors: function () {
            this._navigateToList("Error");
        },

        /**
         * Show only documents with warnings
         */
        onShowWarnings: function () {
            this._navigateToList("Warning");
        },

        /**
         * Show only successful documents
         */
        onShowSuccess: function () {
            this._navigateToList("Success");
        },

        /**
         * Refresh dashboard data
         */
        onRefresh: function () {
            this._loadDashboardData();
        }
    });
});
