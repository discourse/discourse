import Controller from "@ember/controller";
export const DEFAULT_PERIOD = "yearly";

export default Controller.extend({
  loading: false,
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
      }
    ];
  }
});
