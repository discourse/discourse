import RestAdapter from "discourse/adapters/rest";

export default class UserFieldAdapter extends RestAdapter {
  basePath() {
    return "/admin/config/";
  }
}
