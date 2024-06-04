import RestAdapter from "discourse/adapters/rest";

export default class ReviewableTopicAdapter extends RestAdapter {
  pathFor() {
    return "/review/topics";
  }
}
