import Controller from "@ember/controller";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export const DEFAULT_PERIOD = "yearly";

export default class AdminSearchLogsIndexController extends Controller {
  @service siteSettings;

  loading = false;
  period = DEFAULT_PERIOD;
  searchType = "all";

  get searchTypeOptions() {
    return [
      {
        id: "all",
        name: i18n("admin.logs.search_logs.types.all_search_types"),
      },
      {
        id: "non_staff_only",
        name: i18n("admin.logs.search_logs.types.non_staff_only"),
      },
      ...(this.siteSettings.improved_crawler_detection
        ? [
            {
              id: "human_only",
              name: i18n("admin.logs.search_logs.types.human_only"),
            },
          ]
        : []),
      { id: "header", name: i18n("admin.logs.search_logs.types.header") },
      {
        id: "full_page",
        name: i18n("admin.logs.search_logs.types.full_page"),
      },
    ];
  }
}
