import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";

export default class AdminSubscription extends EmberObject {
  static find() {
    return ajax("/s/admin/subscriptions", {
      method: "get",
    }).then((result) => {
      if (result === null) {
        return { unconfigured: true };
      }
      result.data = result.data.map((subscription) =>
        AdminSubscription.create(subscription)
      );
      return result;
    });
  }

  static loadMore(lastRecord) {
    return ajax(`/s/admin/subscriptions?last_record=${lastRecord}`, {
      method: "get",
    }).then((result) => {
      result.data = result.data.map((subscription) =>
        AdminSubscription.create(subscription)
      );
      return result;
    });
  }

  @discourseComputed("status")
  canceled(status) {
    return status === "canceled";
  }

  @discourseComputed("metadata")
  metadataUserExists(metadata) {
    return metadata.user_id && metadata.username;
  }

  @discourseComputed("metadata")
  subscriptionUserPath(metadata) {
    return getURL(`/admin/users/${metadata.user_id}/${metadata.username}`);
  }

  destroy(refund) {
    const data = {
      refund,
    };
    return ajax(`/s/admin/subscriptions/${this.id}`, {
      method: "delete",
      data,
    }).then((result) => AdminSubscription.create(result));
  }
}
