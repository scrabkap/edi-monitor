sap.ui.define([
    "sap/ui/core/UIComponent",
    "sap/ui/model/json/JSONModel",
    "sap/ui/model/odata/v4/ODataModel"
], function (UIComponent, JSONModel, ODataModel) {
    "use strict";

    return UIComponent.extend("edi.monitor.Component", {
        metadata: {
            manifest: "json"
        },

        /**
         * The component is initialized by UI5 automatically during the startup of the app and calls the init method once.
         * @public
         * @override
         */
        init: function () {
            // Call the base component's init function
            UIComponent.prototype.init.apply(this, arguments);

            // ========================================================================
            // SAP BACKEND CONFIGURATION
            // ========================================================================
            // Replace these values with your SAP system details
            const SAP_GATEWAY_HOST = window.location.origin; // Use same origin (e.g., https://sap.company.com)
            const ODATA_SERVICE_PATH = "/sap/opu/odata4/sap/zedi_monitor_srv/srvd/sap/zedi_monitor/0001/";

            // Alternative: For OData V2 (if using older SAP Gateway)
            // const ODATA_SERVICE_PATH = "/sap/opu/odata/sap/ZEDI_MONITOR_SRV/";

            // ========================================================================
            // CREATE ODATA V4 MODEL (SAP Backend)
            // ========================================================================
            const oModel = new ODataModel({
                serviceUrl: ODATA_SERVICE_PATH,
                synchronizationMode: "None",
                operationMode: "Server",
                autoExpandSelect: true,
                earlyRequests: false,
                groupId: "$auto",
                updateGroupId: "updateGroup"
            });

            // Set as default model
            this.setModel(oModel);

            // ========================================================================
            // CREATE VIEW MODEL (for UI state management)
            // ========================================================================
            const oViewModel = new JSONModel({
                busy: false,
                delay: 0
            });
            this.setModel(oViewModel, "view");

            // ========================================================================
            // INITIALIZE ROUTER
            // ========================================================================
            this.getRouter().initialize();

            console.log("EDI Monitor initialized with SAP OData backend:", ODATA_SERVICE_PATH);
        },

        /**
         * This method can be called to determine whether the sapUiSizeCompact or sapUiSizeCozy
         * design mode class should be set, which influences the size appearance of some controls.
         * @public
         * @return {string} css class, either 'sapUiSizeCompact' or 'sapUiSizeCozy' - or an empty string if no css class should be set
         */
        getContentDensityClass: function () {
            if (this._sContentDensityClass === undefined) {
                // check whether FLP has already set the content density class; do nothing in this case
                if (document.body.classList.contains("sapUiSizeCozy") || document.body.classList.contains("sapUiSizeCompact")) {
                    this._sContentDensityClass = "";
                } else if (!Device.support.touch) { // apply "compact" mode if touch is not supported
                    this._sContentDensityClass = "sapUiSizeCompact";
                } else {
                    // "cozy" in case of touch support; default for most sap.m controls, but needed for desktop-first controls like sap.ui.table.Table
                    this._sContentDensityClass = "sapUiSizeCozy";
                }
            }
            return this._sContentDensityClass;
        }
    });
});
