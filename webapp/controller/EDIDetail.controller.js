sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/m/MessageToast",
    "sap/m/MessageBox",
    "sap/ui/core/routing/History"
], function (Controller, JSONModel, MessageToast, MessageBox, History) {
    "use strict";

    return Controller.extend("edi.monitor.controller.EDIDetail", {

        onInit: function () {
            // Initialize detail model
            const oDetailModel = new JSONModel({});
            this.getView().setModel(oDetailModel, "detail");

            // Attach route matched handler
            const oRouter = this.getOwnerComponent().getRouter();
            oRouter.getRoute("ediDetail").attachPatternMatched(this._onRouteMatched, this);
        },

        /**
         * Handle route matched
         * @private
         */
        _onRouteMatched: function (oEvent) {
            const oArgs = oEvent.getParameter("arguments");
            const sDocumentNumber = oArgs.documentNumber;

            this._loadDocumentDetail(sDocumentNumber);
        },

        /**
         * Load document detail
         * @private
         */
        _loadDocumentDetail: function (sDocumentNumber) {
            const oModel = this.getView().getModel("detail");

            // Get EDI data from EDI list model
            const oEDIModel = this.getOwnerComponent().getModel() || new JSONModel();
            const aDocuments = oEDIModel.getProperty("/data") || [];

            // Find the document
            const oDocument = aDocuments.find(doc => doc.document_number === sDocumentNumber);

            if (oDocument) {
                oModel.setData(oDocument);
            } else {
                // If not found in model, load from API
                this._loadFromAPI(sDocumentNumber);
            }
        },

        /**
         * Load document from API
         * @private
         */
        _loadFromAPI: function (sDocumentNumber) {
            const sApiEndpoint = this._getAPIEndpoint();
            const sUrl = sApiEndpoint + "/api/edi-data";

            fetch(sUrl)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.json();
                })
                .then(data => {
                    const oDocument = data.data.find(doc => doc.document_number === sDocumentNumber);
                    if (oDocument) {
                        this.getView().getModel("detail").setData(oDocument);
                    } else {
                        MessageBox.error("Document not found");
                        this.onNavBack();
                    }
                })
                .catch(error => {
                    console.error("Error loading document detail:", error);
                    MessageBox.error("Failed to load document detail: " + error.message);
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
         * Navigate back
         */
        onNavBack: function () {
            const oHistory = History.getInstance();
            const sPreviousHash = oHistory.getPreviousHash();

            if (sPreviousHash !== undefined) {
                window.history.go(-1);
            } else {
                this.getOwnerComponent().getRouter().navTo("ediList", {}, true);
            }
        },

        /**
         * Refresh document data
         */
        onRefresh: function () {
            MessageToast.show(this.getView().getModel("i18n").getResourceBundle().getText("refreshing"));
            const oModel = this.getView().getModel("detail");
            const sDocumentNumber = oModel.getProperty("/document_number");
            this._loadFromAPI(sDocumentNumber);
        }
    });
});
