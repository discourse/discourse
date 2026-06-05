import RestAdapter from "discourse/adapters/rest";

export default class ReviewableAdapter extends RestAdapter {
  jsonMode = true;

  pathFor(store, type, findArgs) {
    return this.appendQueryParams("/review", findArgs);
  }
}
