import RestAdapter from "discourse/adapters/rest";

export default class CustomizationBase extends RestAdapter {
  basePath() {
    return "/admin/customize/";
  }
}
