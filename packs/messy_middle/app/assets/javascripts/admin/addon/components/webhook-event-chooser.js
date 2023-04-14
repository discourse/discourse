import Component from "@glimmer/component";
import I18n from "I18n";

export default class WebhookEventChooser extends Component {
  get name() {
    return I18n.t(`admin.web_hooks.${this.args.type.name}_event.name`);
  }

  get details() {
    return I18n.t(`admin.web_hooks.${this.args.type.name}_event.details`);
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
      return value;
    }

    if (value) {
      eventTypes.addObject(this.args.type);
    } else {
      eventTypes.removeObjects(
        eventTypes.filter((eventType) => eventType.name === this.args.type.name)
      );
    }

    return value;
  }
}
