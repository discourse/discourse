import RestAdapter from "discourse/adapters/rest";

export default class ReviewableExplanationAdapter extends RestAdapter {
  jsonMode = true;

  pathFor(store, type, id) {
    return `/review/${id}/explain.json`;
  }
}
