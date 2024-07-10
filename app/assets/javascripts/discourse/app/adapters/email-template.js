import RestAdapter from "discourse/adapters/rest";

export default class EmailTemplateAdapter extends RestAdapter {
  basePath() {
    return "/admin/customize/";
  }
}
