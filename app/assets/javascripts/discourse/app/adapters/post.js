import RestAdapter, { Result } from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";
import { underscore } from "@ember/string";

export default RestAdapter.extend({
  find(store, type, findArgs) {
    return this._super(store, type, findArgs).then(function (result) {
      console.log("result: ", result)
      return { post: result };
    });
  },

  createRecord(store, type, args) {
    console.log("app/assets/javascripts/discourse/app/adapters/post.js ==============")
    console.log("@param store: ", store)
    console.log("@param type: ", type)
    console.log("@param agrs: ", args)
    const typeField = underscore(type);
    args.nested_post = true;
    return ajax(this.pathFor(store, type), { type: "POST", data: args }).then(
      function (json) {
        return new Result(json[typeField], json);
      }
    );
  },
});
