import Component from "@glimmer/component";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import bodyClass from "discourse/helpers/body-class";
import KeyValueStore from "discourse/lib/key-value-store";

export default class AvatarDecorator extends Component {
  @service currentUser;

  store = new TrackedObject(
    new KeyValueStore("discourse_rewind_" + this.fetchYear)
  );

  get fetchYear() {
    const currentDate = new Date();
    const currentMonth = currentDate.getMonth();
    const currentYear = currentDate.getFullYear();

    if (currentMonth === 0) {
      return currentYear - 1;
    } else {
      return currentYear;
    }
  }

  get dismissed() {
    return this.store.getObject("_dismissed") ?? false;
  }

  get showDecorator() {
    return (
      this.currentUser?.is_development_env ||
      (this.currentUser?.is_rewind_active && !this.dismissed)
    );
  }

  <template>
    {{#if this.showDecorator}}
      {{bodyClass "rewind-notification-active"}}
    {{/if}}
  </template>
}
