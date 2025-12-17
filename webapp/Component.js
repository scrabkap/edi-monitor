sap.ui.define([
    "sap/ui/core/UIComponent",
    "sap/ui/Device",
    "edi/monitor/model/models",
    "sap/ui/model/json/JSONModel"
], function (UIComponent, Device, models, JSONModel) {
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
            // call the base component's init function
            UIComponent.prototype.init.apply(this, arguments);

            // enable routing
            this.getRouter().initialize();

            // set the device model
            this.setModel(models.createDeviceModel(), "device");

            // set API endpoint configuration
            const apiEndpoint = this._getAPIEndpoint();
            const configModel = new JSONModel({
                apiEndpoint: apiEndpoint
            });
            this.setModel(configModel, "config");

            console.log("EDI Monitor initialized with API endpoint:", apiEndpoint);
        },

        /**
         * Get API endpoint based on environment
         * @private
         */
        _getAPIEndpoint: function () {
            // In production, this would be configured via environment variable or config file
            // For now, check if running locally or deployed
            const hostname = window.location.hostname;

            if (hostname === "localhost" || hostname === "127.0.0.1") {
                // Local development - use placeholder or local API Gateway URL
                return "https://your-api-id.execute-api.region.amazonaws.com/dev";
            } else {
                // Production - API endpoint should be in same domain or configured
                return window.location.origin;
            }
        }
    });
});
