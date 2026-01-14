import RestAdapter from "discourse/adapters/rest";

export default class PendingPostAdapter extends RestAdapter {
  jsonMode = true;

  pathFor(_store, _type, params) {
    return `/posts/${params.username}/pending.json`;
  }
}
