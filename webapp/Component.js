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
            // API endpoint injected during deployment
            // This line will be replaced by the deployment script
            return "https://your-api-id.execute-api.eu-west-1.amazonaws.com/dev";
        },

        /**
         * Get content density class
         * @public
         * @returns {string} CSS class for content density
         */
        getContentDensityClass: function () {
            if (!this._sContentDensityClass) {
                if (!Device.support.touch) {
                    this._sContentDensityClass = "sapUiSizeCompact";
                } else {
                    this._sContentDensityClass = "sapUiSizeCozy";
                }
            }
            return this._sContentDensityClass;
        }
    });
});
