import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

export default class PostLocalization extends RestModel {
  static find(postId) {
    return ajax(`/post_localizations/${postId}`, {
      type: "GET",
      data: {
        post_id: postId,
      },
    });
  }

  static createOrUpdate(postId, locale, raw) {
    return ajax("/post_localizations/create_or_update", {
      type: "POST",
      data: {
        post_id: postId,
        locale,
        raw,
      },
    });
  }

  static destroy(postId, locale) {
    return ajax("/post_localizations/destroy", {
      type: "DELETE",
      data: {
        post_id: postId,
        locale,
      },
    });
  }
}
