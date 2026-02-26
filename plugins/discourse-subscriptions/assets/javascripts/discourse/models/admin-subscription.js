import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
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

  @computed("status")
  get canceled() {
    return this.status === "canceled";
  }

  @computed("metadata")
  get metadataUserExists() {
    return this.metadata.user_id && this.metadata.username;
  }

  @computed("metadata")
  get subscriptionUserPath() {
    return getURL(
      `/admin/users/${this.metadata.user_id}/${this.metadata.username}`
    );
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
