import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class BlogReviewRoute extends DiscourseRoute {
  queryParams = { review_token: { refreshModel: true } };

  #previousHeader;
  #previousSidebar;

  activate() {
    const application = this.controllerFor("application");
    this.#previousHeader = application.showSiteHeader;
    this.#previousSidebar = application.sidebarDisabledRouteOverride;
    application.setProperties({
      showSiteHeader: false,
      sidebarDisabledRouteOverride: true,
    });
  }

  deactivate() {
    this.controllerFor("application").setProperties({
      showSiteHeader: this.#previousHeader,
      sidebarDisabledRouteOverride: this.#previousSidebar,
    });
  }

  titleToken() {
    return this.currentModel?.title || i18n("blog.review.page_title");
  }

  async model({ review_token }) {
    try {
      const review = await ajax("/blog/review.json", {
        data: { review_token },
      });
      return { ...review, token: review_token };
    } catch (error) {
      if ([403, 404].includes(error.jqXHR?.status)) {
        return { unavailable: true };
      }
      throw error;
    }
  }
}
