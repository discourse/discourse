import ChangeSiteCustomizationDetailsController from "admin/controllers/modals/change-site-customization-details";

export default ChangeSiteCustomizationDetailsController.extend({
  onShow: function() {
    this.send("selectPrevious");
  }
});
