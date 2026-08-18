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
    "username",
    "unattributed",
    "id_type",
    "id_value",
    "details",
  ];

  period = null;
  start_date = null;
  end_date = null;
  outcome = null;
  has_retries = null;
  selectedModel = null;
  feature = null;
  username = null;
  unattributed = null;
  id_type = null;
  id_value = null;
  details = null;
}
