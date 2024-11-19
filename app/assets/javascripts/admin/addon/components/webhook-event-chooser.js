import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class WebhookEventChooser extends Component {
  get details() {
    return i18n(
      `admin.web_hooks.${this.args.group}_event.${this.args.type.name}`
    );
  }

  get eventTypeExists() {
    return this.args.eventTypes.any(
      (event) => event.name === this.args.type.name
    );
  }

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
      eventTypes.addObject(this.args.type);
    } else {
      eventTypes.removeObjects(
        eventTypes.filter((eventType) => eventType.name === this.args.type.name)
      );
    }
  }
}
