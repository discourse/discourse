import ChangeSiteCustomizationDetailsController from "admin/controllers/change-site-customization-details";

export default ChangeSiteCustomizationDetailsController.extend({
  onShow: function() {
    this.selectPrevious();
  }
});
