import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";

@tagName("")
export default class TopicNavigationPopup extends Component {
  popupId = null;
  hidden = false;

  init() {
    super.init(...arguments);

    if (this.popupKey) {
      const value = this.keyValueStore.getItem(this.popupKey);
      if (value === true || value > +new Date()) {
        this.set("hidden", true);
      } else {
        this.keyValueStore.removeItem(this.popupKey);
      }
    }
  }

  @discourseComputed("popupId")
  popupKey(popupId) {
    if (popupId) {
      return `dismiss_topic_nav_popup_${popupId}`;
    }
  }

  @action
  close() {
    this.set("hidden", true);

    if (this.popupKey) {
      if (this.dismissDuration) {
        const expiry = +new Date() + this.dismissDuration;
        this.keyValueStore.setItem(this.popupKey, expiry);
      } else {
        this.keyValueStore.setItem(this.popupKey, true);
      }
    }
  }
}
