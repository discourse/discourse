import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  jsonMode: true,

  pathFor(_store, _type, params) {
    return `/posts/${params.username}/pending.json`;
  },
});
