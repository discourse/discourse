import RESTAdapter from "discourse/adapters/rest";

export default class TagInfoAdapter extends RESTAdapter {
  pathFor(store, type, findArgs) {
    if (typeof findArgs === "string" && findArgs.includes("/")) {
      return `/tag/${findArgs}/info.json`;
    }
    return `/tag/${findArgs}/info.json`;
  }
}
