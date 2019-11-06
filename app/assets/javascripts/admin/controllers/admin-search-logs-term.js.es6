import Controller from "@ember/controller";
import { DEFAULT_PERIOD } from "admin/controllers/admin-search-logs-index";

export default Controller.extend({
  loading: false,
  term: null,
  period: DEFAULT_PERIOD,
  searchType: "all",

  init() {
    this._super(...arguments);

    this.searchTypeOptions = [
      {
        id: "all",
        name: I18n.t("admin.logs.search_logs.types.all_search_types")
      },
      { id: "header", name: I18n.t("admin.logs.search_logs.types.header") },
      {
        id: "full_page",
        name: I18n.t("admin.logs.search_logs.types.full_page")
      },
      {
        id: "click_through_only",
        name: I18n.t("admin.logs.search_logs.types.click_through_only")
      }
    ];
  }
});
