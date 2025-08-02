import Category from "discourse/models/category";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesNavigationMenu extends RestrictedUserRoute {
  setupController(controller, user) {
    const props = {
      model: user,
      selectedSidebarCategories: Category.findByIds(user.sidebarCategoryIds),
      newSidebarLinkToFilteredList: user.sidebarLinkToFilteredList,
      newSidebarShowCountOfNewItems: user.sidebarShowCountOfNewItems,
    };

    if (this.siteSettings.tagging_enabled) {
      props.selectedSidebarTagNames = user.sidebarTagNames;
    }

    controller.setProperties(props);
  }
}
