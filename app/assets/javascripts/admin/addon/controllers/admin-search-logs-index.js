import Controller from "@ember/controller";
import I18n from "I18n";
export const DEFAULT_PERIOD = "yearly";

export default class AdminSearchLogsIndexController extends Controller {
  loading = false;
  period = DEFAULT_PERIOD;
  searchType = "all";

  init() {
    super.init(...arguments);

    this.searchTypeOptions = [
      {
        id: "all",
        name: I18n.t("admin.logs.search_logs.types.all_search_types"),
      },
      { id: "header", name: I18n.t("admin.logs.search_logs.types.header") },
      {
        id: "full_page",
        name: I18n.t("admin.logs.search_logs.types.full_page"),
      },
    ];
  }
}
