import Controller from "@ember/controller";
import EmberObject, { action, computed } from "@ember/object";
import { service } from "@ember/service";

const ALL_FILTER = "all";

export default class AdminEmojisNewController extends Controller {
  @service router;

  @computed("model")
  get emojiGroups() {
    return this.model.mapBy("group").uniq();
  }

  @computed("emojiGroups.[]")
  get sortingGroups() {
    return [ALL_FILTER].concat(this.emojiGroups);
  }

  @action
  emojiUploaded(emoji, group) {
    emoji.url += "?t=" + new Date().getTime();
    emoji.group = group;
    this.model.pushObject(EmberObject.create(emoji));
    this.router.transitionTo("adminEmojis.index");
  }
}
