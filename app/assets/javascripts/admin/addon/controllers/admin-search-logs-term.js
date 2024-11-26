import Controller from "@ember/controller";
import { i18n } from "discourse-i18n";
import { DEFAULT_PERIOD } from "admin/controllers/admin-search-logs-index";

export default class AdminSearchLogsTermController extends Controller {
  loading = false;
  term = null;
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
    {
      id: "click_through_only",
      name: i18n("admin.logs.search_logs.types.click_through_only"),
    },
  ];

  get chartConfig() {
    return {
      type: "bar",
      data: {
        labels: this.model.data.map((r) => r.x),
        datasets: [
          {
            data: this.model.data.map((r) => r.y),
            label: this.model.title,
            backgroundColor: "rgba(200,220,240,1)",
            borderColor: "#08C",
          },
        ],
      },
      options: {
        responsive: true,
        plugins: {
          tooltip: {
            callbacks: {
              title: (context) =>
                moment(context[0].label, "YYYY-MM-DD").format("LL"),
            },
          },
        },
        scales: {
          y: [
            {
              display: true,
              ticks: {
                stepSize: 1,
              },
            },
          ],
        },
      },
    };
  }
}
