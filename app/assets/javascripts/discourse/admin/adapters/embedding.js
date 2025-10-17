import RestAdapter from "discourse/adapters/rest";

export default class Embedding extends RestAdapter {
  pathFor() {
    return "/admin/customize/embedding";
  }
}
