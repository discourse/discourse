import RESTAdapter from "discourse/adapters/rest";

export default class TagAdapter extends RESTAdapter {
  pathFor(store, type, findArgs) {
    return findArgs ? `/tag/${findArgs}.json` : `/tags.json`;
  }
}
