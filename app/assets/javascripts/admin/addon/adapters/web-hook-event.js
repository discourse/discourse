import RESTAdapter from "discourse/adapters/rest";

export default class WebHookEvent extends RESTAdapter {
  basePath() {
    return "/admin/api/";
  }
}
