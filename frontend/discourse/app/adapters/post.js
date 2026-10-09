import { underscore } from "@ember/string";
import RestAdapter, { Result } from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class PostAdapter extends RestAdapter {
  update(store, type, id, attrs) {
    const { reviewableAction, ...edit } = attrs;
    if (!reviewableAction) {
      return super.update(store, type, id, attrs);
    }

    return ajax(
      `/review/${reviewableAction.id}/perform/${reviewableAction.action}`,
      {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          ...reviewableAction.data,
          version: reviewableAction.version,
          edit,
        }),
      }
    ).then((json) => new Result(json.post, json));
  }

  find(store, type, findArgs) {
    return super.find(store, type, findArgs).then(function (result) {
      return { post: result };
    });
  }

  createRecord(store, type, args) {
    const typeField = underscore(type);
    // "nested_post" is unrelated to the nested replies feature — it tells
    // the server to return the full JSON envelope ({post, action, success})
    // instead of the bare post object (legacy API compat).
    args.nested_post = true;
    return ajax(this.pathFor(store, type), {
      type: "POST",
      data: JSON.stringify(args),
      contentType: "application/json",
    }).then(function (json) {
      return new Result(json[typeField], json);
    });
  }
}
