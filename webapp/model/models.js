sap.ui.define([
    "sap/ui/model/json/JSONModel",
    "sap/ui/Device"
], function (JSONModel, Device) {
    "use strict";

    return {
        /**
         * Creates device model
         * @returns {sap.ui.model.json.JSONModel} Device model
         */
        createDeviceModel: function () {
            var oModel = new JSONModel(Device);
            oModel.setDefaultBindingMode("OneWay");
            return oModel;
        },

        /**
         * Creates EDI data model
         * @returns {sap.ui.model.json.JSONModel} EDI model
         */
        createEDIModel: function () {
            return new JSONModel({
                documents: [],
                loading: false,
                error: null
            });
        },

        /**
         * Creates dashboard model
         * @returns {sap.ui.model.json.JSONModel} Dashboard model
         */
        createDashboardModel: function () {
            return new JSONModel({
                totalDocuments: 0,
                errorDocuments: 0,
                warningDocuments: 0,
                successDocuments: 0,
                errorRate: 0,
                recentErrors: [],
                loading: false
            });
        }
    };
});
