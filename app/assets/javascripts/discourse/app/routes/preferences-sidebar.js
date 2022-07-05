import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    const props = {
      model: user,
      selectedSiderbarCategories: user.sidebarCategories,
      initialSidebarCategoryIds: user.sidebarCategoryIds,
    };

    if (this.siteSettings.tagging_enabled) {
      props.selectedSidebarTagNames = user.sidebarTagNames;
      props.initialSidebarTagNames = user.sidebarTagNames;
    }

    controller.setProperties(props);
  },
});
