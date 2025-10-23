import RestAdapter from "discourse/adapters/rest";

export default class ApiKey extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/api/";
  }

  apiNameFor() {
    return "key";
  }
}
