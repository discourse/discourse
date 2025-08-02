import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

// For use in plugins
export default class TopicNavigationPopup extends Component {
  @service keyValueStore;

  @tracked hidden = false;

  constructor() {
    super(...arguments);

    if (this.popupKey) {
      const value = this.keyValueStore.getItem(this.popupKey);

      if (value === true || value > +new Date()) {
        this.hidden = true;
      } else {
        this.keyValueStore.removeItem(this.popupKey);
      }
    }
  }

  get popupKey() {
    if (this.args.popupId) {
      return `dismiss_topic_nav_popup_${this.args.popupId}`;
    }
  }

  @action
  close() {
    this.hidden = true;

    if (this.popupKey) {
      if (this.args.dismissDuration) {
        const expiry = +new Date() + this.args.dismissDuration;
        this.keyValueStore.setItem(this.popupKey, expiry);
      } else {
        this.keyValueStore.setItem(this.popupKey, true);
      }
    }
  }

  <template>
    {{#unless this.hidden}}
      <div class="topic-navigation-popup">
        <DButton @action={{this.close}} @icon="xmark" class="close btn-flat" />
        {{yield}}
      </div>
    {{/unless}}
  </template>
}
