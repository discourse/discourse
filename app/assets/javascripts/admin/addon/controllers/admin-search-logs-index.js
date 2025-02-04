import Controller from "@ember/controller";
import { i18n } from "discourse-i18n";
export const DEFAULT_PERIOD = "yearly";

export default class AdminSearchLogsIndexController extends Controller {
  loading = false;
  period = DEFAULT_PERIOD;
  searchType = "all";
  searchTypeOptions = [
    {
      id: "all",
      name: i18n("admin.logs.search_logs.types.all_search_types"),
    },
    { id: "header", name: i18n("admin.logs.search_logs.types.header") },
    {
      id: "full_page",
      name: i18n("admin.logs.search_logs.types.full_page"),
    },
  ];
}
