import RestAdapter from "discourse/adapters/rest";

export default class WebHook extends RestAdapter {
  basePath() {
    return "/admin/api/";
  }
}
