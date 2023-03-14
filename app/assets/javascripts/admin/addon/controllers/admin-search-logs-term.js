import Controller from "@ember/controller";
import { DEFAULT_PERIOD } from "admin/controllers/admin-search-logs-index";
import I18n from "I18n";

export default class AdminSearchLogsTermController extends Controller {
  loading = false;
  term = null;
  period = DEFAULT_PERIOD;
  searchType = "all";
  searchTypeOptions = [
    {
      id: "all",
      name: I18n.t("admin.logs.search_logs.types.all_search_types"),
    },
    { id: "header", name: I18n.t("admin.logs.search_logs.types.header") },
    {
      id: "full_page",
      name: I18n.t("admin.logs.search_logs.types.full_page"),
    },
    {
      id: "click_through_only",
      name: I18n.t("admin.logs.search_logs.types.click_through_only"),
    },
  ];
}
