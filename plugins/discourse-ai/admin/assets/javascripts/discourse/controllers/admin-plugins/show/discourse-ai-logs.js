import Controller from "@ember/controller";

export default class DiscourseAiLogsController extends Controller {
  queryParams = [
    "period",
    "start_date",
    "end_date",
    "outcome",
    "has_retries",
    { selectedModel: "model" },
    "feature",
    "search",
    "unattributed",
    "details",
  ];

  period = null;
  start_date = null;
  end_date = null;
  outcome = null;
  has_retries = null;
  selectedModel = null;
  feature = null;
  search = null;
  unattributed = null;
  details = null;
}
