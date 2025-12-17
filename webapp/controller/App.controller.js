sap.ui.define([
    "sap/ui/core/mvc/Controller"
], function (Controller) {
    "use strict";

    return Controller.extend("edi.monitor.controller.App", {
        onInit: function () {
            // Apply content density mode based on device
            this.getView().addStyleClass(this.getOwnerComponent().getContentDensityClass());
        }
    });
});
