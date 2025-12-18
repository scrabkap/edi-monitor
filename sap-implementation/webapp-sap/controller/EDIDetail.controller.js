sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator"
], function (Controller, JSONModel, Filter, FilterOperator) {
    "use strict";

    return Controller.extend("edi.monitor.controller.EDIDetail", {

        onInit: function () {
            // Initialize view model
            const oViewModel = new JSONModel({
                busy: false,
                itemStatusFilter: "",
                documentNumber: ""
            });
            this.getView().setModel(oViewModel, "view");

            // Get router and attach route matched event
            const oRouter = this.getOwnerComponent().getRouter();
            oRouter.getRoute("ediDetail").attachPatternMatched(this._onRouteMatched, this);
        },

        /**
         * Route matched - load document data
         * @private
         */
        _onRouteMatched: function (oEvent) {
            const oArgs = oEvent.getParameter("arguments");
            const sDocumentId = oArgs.documentId;

            const oViewModel = this.getView().getModel("view");
            oViewModel.setProperty("/documentNumber", sDocumentId);
            oViewModel.setProperty("/busy", true);

            // ========================================================================
            // ODATA V4: Bind element to document with items expanded
            // ========================================================================
            // URL: /EDIDocuments('43681')?$expand=Items
            const oModel = this.getView().getModel();

            this.getView().bindElement({
                path: `/EDIDocuments('${sDocumentId}')`,
                parameters: {
                    $expand: "Items" // Load items with document
                },
                events: {
                    dataRequested: () => {
                        oViewModel.setProperty("/busy", true);
                    },
                    dataReceived: (oEvent) => {
                        oViewModel.setProperty("/busy", false);
                        const oData = oEvent.getParameter("data");
                        if (!oData) {
                            this._showNotFoundMessage();
                        }
                    },
                    change: () => {
                        const oElementBinding = this.getView().getElementBinding();
                        if (!oElementBinding.getBoundContext()) {
                            this._showNotFoundMessage();
                        }
                    }
                }
            });
        },

        /**
         * Show message when document not found
         * @private
         */
        _showNotFoundMessage: function () {
            const oViewModel = this.getView().getModel("view");
            oViewModel.setProperty("/busy", false);

            sap.m.MessageBox.error(
                "Document not found. It may have been deleted or you don't have permission to access it.",
                {
                    title: "Not Found",
                    actions: [sap.m.MessageBox.Action.OK],
                    onClose: () => {
                        this.onNavBack();
                    }
                }
            );
        },

        /**
         * Filter items by status (Error, Warning, Success, All)
         */
        onItemFilterChange: function (oEvent) {
            const sKey = oEvent.getParameter("item").getKey();
            const oTable = this.byId("itemsTable");
            const oBinding = oTable.getBinding("items");

            if (!oBinding) {
                return;
            }

            // Apply filter
            const aFilters = [];
            if (sKey) {
                aFilters.push(new Filter("Severity", FilterOperator.EQ, sKey));
            }

            oBinding.filter(aFilters);
        },

        /**
         * Refresh document and items
         */
        onRefresh: function () {
            const oElementBinding = this.getView().getElementBinding();
            if (oElementBinding) {
                oElementBinding.refresh();
            }

            // Also refresh items table
            const oTable = this.byId("itemsTable");
            const oBinding = oTable.getBinding("items");
            if (oBinding) {
                oBinding.refresh();
            }

            sap.m.MessageToast.show("Data refreshed");
        },

        /**
         * Navigate back to list
         */
        onNavBack: function () {
            const oHistory = sap.ui.core.routing.History.getInstance();
            const sPreviousHash = oHistory.getPreviousHash();

            if (sPreviousHash !== undefined) {
                window.history.go(-1);
            } else {
                const oRouter = this.getOwnerComponent().getRouter();
                oRouter.navTo("ediList", {}, true);
            }
        },

        /**
         * Show material document (if exists)
         */
        onShowMaterialDocument: function () {
            const oElementBinding = this.getView().getElementBinding();
            const oContext = oElementBinding.getBoundContext();

            if (oContext) {
                const sMblnr = oContext.getProperty("MaterialDocument");
                const sMjahr = oContext.getProperty("MaterialDocumentYear");

                if (sMblnr && sMjahr) {
                    sap.m.MessageToast.show(`Opening Material Document ${sMblnr}/${sMjahr}`);
                    // TODO: Navigate to SAP MM document display (MIGO/MB03)
                    // Could use: /sap/bc/gui/sap/its/webgui?~transaction=MB03&RM07M-MBLNR=${sMblnr}&RM07M-MJAHR=${sMjahr}
                } else {
                    sap.m.MessageToast.show("No material document available");
                }
            }
        },

        /**
         * Show sales document (if exists)
         */
        onShowSalesDocument: function () {
            const oElementBinding = this.getView().getElementBinding();
            const oContext = oElementBinding.getBoundContext();

            if (oContext) {
                const sVbeln = oContext.getProperty("SalesDocument");

                if (sVbeln) {
                    sap.m.MessageToast.show(`Opening Sales Document ${sVbeln}`);
                    // TODO: Navigate to SAP SD document display (VA03)
                    // Could use: /sap/bc/gui/sap/its/webgui?~transaction=VA03&VBAK-VBELN=${sVbeln}
                } else {
                    sap.m.MessageToast.show("No sales document available");
                }
            }
        },

        /**
         * Download document as PDF (example)
         */
        onDownload: function () {
            sap.m.MessageToast.show("Download functionality - to be implemented");
            // Could generate PDF report of document and items
        }
    });
});
