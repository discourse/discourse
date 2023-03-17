import RESTAdapter from "discourse/adapters/rest";

export default class ApiKey extends RESTAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/api/";
  }

  apiNameFor() {
    return "key";
  }
}
