import Component from "@glimmer/component";
import { Input } from "@ember/component";
import {
  addUniqueValueToArray,
  removeValuesFromArray,
} from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";

export default class WebhookEventChooser extends Component {
  get enabled() {
    return this.eventTypeExists;
  }

  set enabled(value) {
    const eventTypes = this.args.eventTypes;

    // add an association when not exists
    if (value === this.eventTypeExists) {
      return;
    }

    if (value) {
      addUniqueValueToArray(eventTypes, this.args.type);
    } else {
      removeValuesFromArray(
        eventTypes,
        eventTypes.filter((eventType) => eventType.name === this.args.type.name)
      );
    }
  }

  get details() {
    return i18n(
      `admin.web_hooks.${this.args.group}_event.${this.args.type.name}`
    );
  }

  get eventTypeExists() {
    return this.args.eventTypes.some(
      (event) => event.name === this.args.type.name
    );
  }

  <template>
    <label class="hook-event">
      <Input name="event-choice" @checked={{this.enabled}} @type="checkbox" />
      {{this.details}}
    </label>
  </template>
}
