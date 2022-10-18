import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    const props = {
      model: user,
      selectedSidebarCategories: user.sidebarCategories,
    };

    if (this.siteSettings.tagging_enabled) {
      props.selectedSidebarTagNames = user.sidebarTagNames;
    }
    props.newSidebarListDestination = user.sidebarListDestination;

    controller.setProperties(props);
  },
});
