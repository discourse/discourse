import RestAdapter from "discourse/adapters/rest";

export default class Permalink extends RestAdapter {
  basePath() {
    return "/admin/";
  }
}
