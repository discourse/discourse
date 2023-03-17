import RESTAdapter from "discourse/adapters/rest";

export default class WebHook extends RESTAdapter {
  basePath() {
    return "/admin/api/";
  }
}
