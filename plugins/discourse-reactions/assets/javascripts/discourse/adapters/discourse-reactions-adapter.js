import RestAdapter from "discourse/adapters/rest";

export default class DiscourseReactionsAdapter extends RestAdapter {
  basePath() {
    return "/discourse-reactions/";
  }
}
