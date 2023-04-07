import RestAdapter from "discourse/adapters/rest";

export default class StaffActionLog extends RestAdapter {
  basePath() {
    return "/admin/logs/";
  }
}
