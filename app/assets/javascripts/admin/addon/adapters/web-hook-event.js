import RestAdapter from "discourse/adapters/rest";

export default class WebHookEvent extends RestAdapter {
  basePath() {
    return "/admin/api/";
  }
}
