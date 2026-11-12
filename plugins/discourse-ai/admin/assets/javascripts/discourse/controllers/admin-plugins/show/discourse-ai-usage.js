import Controller from "@ember/controller";

export default class DiscourseAiUsageController extends Controller {
  queryParams = [
    "period",
    "start_date",
    "end_date",
    "feature",
    { selectedModel: "model" },
  ];

  period = null;
  start_date = null;
  end_date = null;
  feature = null;
  selectedModel = null;
}
