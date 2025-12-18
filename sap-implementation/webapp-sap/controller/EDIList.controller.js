sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/ui/model/Sorter"
], function (Controller, JSONModel, Filter, FilterOperator, Sorter) {
    "use strict";

    return Controller.extend("edi.monitor.controller.EDIList", {

        onInit: function () {
            // Initialize view model
            const oViewModel = new JSONModel({
                severityFilter: "",
                storeFilter: "",
                vendorFilter: "",
                documentFilter: "",
                dateRange: null,
                busy: false,
                count: 0
            });
            this.getView().setModel(oViewModel, "view");

            // Get router and attach route matched event
            const oRouter = this.getOwnerComponent().getRouter();
            oRouter.getRoute("ediList").attachPatternMatched(this._onRouteMatched, this);
        },

        /**
         * Route matched - apply severity filter from navigation
         * @private
         */
        _onRouteMatched: function (oEvent) {
            const oArgs = oEvent.getParameter("arguments");
            const sSeverity = oArgs.severity || "";

            const oViewModel = this.getView().getModel("view");
            oViewModel.setProperty("/severityFilter", sSeverity);

            // Apply filter
            this._applyFilters();
        },

        /**
         * Apply all filters to the table binding
         * @private
         */
        _applyFilters: function () {
            const oTable = this.byId("ediTable");
            const oBinding = oTable.getBinding("items");

            if (!oBinding) {
                return;
            }

            const oViewModel = this.getView().getModel("view");
            const aFilters = [];

            // ========================================================================
            // SEVERITY FILTER (from navigation or segmented button)
            // ========================================================================
            const sSeverity = oViewModel.getProperty("/severityFilter");
            if (sSeverity) {
                aFilters.push(new Filter("Severity", FilterOperator.EQ, sSeverity));
            }

            // ========================================================================
            // STORE FILTER (contains search)
            // ========================================================================
            const sStore = oViewModel.getProperty("/storeFilter");
            if (sStore) {
                aFilters.push(new Filter("StoreName", FilterOperator.Contains, sStore));
            }

            // ========================================================================
            // VENDOR FILTER (contains search)
            // ========================================================================
            const sVendor = oViewModel.getProperty("/vendorFilter");
            if (sVendor) {
                aFilters.push(new Filter("VendorName", FilterOperator.Contains, sVendor));
            }

            // ========================================================================
            // DOCUMENT NUMBER FILTER (contains search)
            // ========================================================================
            const sDocument = oViewModel.getProperty("/documentFilter");
            if (sDocument) {
                aFilters.push(new Filter("DocumentNumber", FilterOperator.Contains, sDocument));
            }

            // ========================================================================
            // DATE RANGE FILTER (custom filter function)
            // ========================================================================
            const oDateRange = oViewModel.getProperty("/dateRange");
            if (oDateRange && oDateRange.from && oDateRange.to) {
                // For OData V4, use date range filter
                // Note: May need to adjust based on your backend date format
                aFilters.push(new Filter({
                    filters: [
                        new Filter("ProcessingDate", FilterOperator.GE, this._formatDate(oDateRange.from)),
                        new Filter("ProcessingDate", FilterOperator.LE, this._formatDate(oDateRange.to))
                    ],
                    and: true
                }));
            }

            // Apply filters to binding
            oBinding.filter(aFilters);

            // Update count
            oBinding.requestContexts(0, Infinity).then((aContexts) => {
                oViewModel.setProperty("/count", aContexts.length);
            });
        },

        /**
         * Format date to YYYYMMDD for SAP backend
         * @private
         */
        _formatDate: function (oDate) {
            const sYear = oDate.getFullYear().toString();
            const sMonth = (oDate.getMonth() + 1).toString().padStart(2, '0');
            const sDay = oDate.getDate().toString().padStart(2, '0');
            return sYear + sMonth + sDay;
        },

        /**
         * Severity filter changed (segmented button)
         */
        onFilterChange: function (oEvent) {
            const sKey = oEvent.getParameter("item").getKey();
            const oViewModel = this.getView().getModel("view");
            oViewModel.setProperty("/severityFilter", sKey);
            this._applyFilters();
        },

        /**
         * Quick filter changed (store, vendor, document)
         */
        onQuickFilterChange: function () {
            this._applyFilters();
        },

        /**
         * Date range changed
         */
        onDateRangeChange: function (oEvent) {
            const oDateRange = oEvent.getSource();
            const oViewModel = this.getView().getModel("view");
            oViewModel.setProperty("/dateRange", {
                from: oDateRange.getDateValue(),
                to: oDateRange.getSecondDateValue()
            });
            this._applyFilters();
        },

        /**
         * Clear all filters
         */
        onClearFilters: function () {
            const oViewModel = this.getView().getModel("view");
            oViewModel.setProperty("/storeFilter", "");
            oViewModel.setProperty("/vendorFilter", "");
            oViewModel.setProperty("/documentFilter", "");
            oViewModel.setProperty("/dateRange", null);

            this.byId("dateRangeFilter").setDateValue(null);
            this.byId("dateRangeFilter").setSecondDateValue(null);

            this._applyFilters();
        },

        /**
         * Toggle advanced filter toolbar visibility
         */
        onOpenFilterDialog: function () {
            const oFilterToolbar = this.byId("filterToolbar");
            const bVisible = oFilterToolbar.getVisible();
            oFilterToolbar.setVisible(!bVisible);
        },

        /**
         * Search in document number, store name, vendor name
         */
        onSearch: function (oEvent) {
            const sQuery = oEvent.getParameter("query") || oEvent.getParameter("newValue");
            const oTable = this.byId("ediTable");
            const oBinding = oTable.getBinding("items");

            if (!oBinding) {
                return;
            }

            // Create search filter (searches across multiple fields)
            let aFilters = [];
            if (sQuery) {
                aFilters.push(new Filter({
                    filters: [
                        new Filter("DocumentNumber", FilterOperator.Contains, sQuery),
                        new Filter("StoreName", FilterOperator.Contains, sQuery),
                        new Filter("VendorName", FilterOperator.Contains, sQuery)
                    ],
                    and: false // OR condition
                }));
            }

            oBinding.filter(aFilters);
        },

        /**
         * Navigate to document detail page
         */
        onDocumentSelect: function (oEvent) {
            const oItem = oEvent.getParameter("listItem");
            const oContext = oItem.getBindingContext();
            const sDocNumber = oContext.getProperty("DocumentNumber");

            this.getOwnerComponent().getRouter().navTo("ediDetail", {
                documentId: sDocNumber
            });
        },

        /**
         * Refresh table data
         */
        onRefresh: function () {
            const oTable = this.byId("ediTable");
            const oBinding = oTable.getBinding("items");
            if (oBinding) {
                oBinding.refresh();
            }
        },

        /**
         * Table update finished - update count
         */
        onUpdateFinished: function (oEvent) {
            const oViewModel = this.getView().getModel("view");
            const iTotalItems = oEvent.getParameter("total");
            oViewModel.setProperty("/count", iTotalItems);
        },

        /**
         * Export to Excel
         */
        onExport: function () {
            sap.m.MessageToast.show("Export functionality - to be implemented");
            // Use sap.ui.export library for Excel export
        },

        /**
         * Navigate back
         */
        onNavBack: function () {
            window.history.go(-1);
        }
    });
});
