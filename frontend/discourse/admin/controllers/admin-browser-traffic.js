import Controller from "@ember/controller";

export default class AdminBrowserTrafficController extends Controller {
  queryParams = [
    "start_date",
    "end_date",
    "url",
    "source",
    "country",
    "network",
    "ip",
    "browser",
  ];

  start_date = null;
  end_date = null;
  url = null;
  source = null;
  country = null;
  network = null;
  ip = null;
  browser = null;
}
