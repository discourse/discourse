import RESTAdapter from "discourse/adapters/rest";

export default class TagNotificationAdapter extends RESTAdapter {
  pathFor(store, type, findArgs) {
    if (typeof findArgs === "string" && findArgs.includes("/")) {
      return `/tag/${findArgs}/notifications.json`;
    }
    return `/tag/${findArgs}/notifications.json`;
  }
}
