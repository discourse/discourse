import RestAdapter from "discourse/adapters/rest";

export default class DiscoursePostEventAdapter extends RestAdapter {
  basePath() {
    return "/discourse-post-event/";
  }
}
