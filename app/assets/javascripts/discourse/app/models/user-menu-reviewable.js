import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";

const DEFAULT_COMPONENT = "user-menu/default-reviewable-item";

const DEFAULT_ITEM_COMPONENTS = {
  ReviewableFlaggedPost: "user-menu/reviewable-flagged-post-item",
  ReviewableQueuedPost: "user-menu/reviewable-queued-post-item",
  ReviewableUser: "user-menu/reviewable-user-item",
};

export default class UserMenuReviewable extends RestModel {
  @tracked pending;

  get userMenuComponent() {
    return DEFAULT_ITEM_COMPONENTS[this.type] || DEFAULT_COMPONENT;
  }
}
