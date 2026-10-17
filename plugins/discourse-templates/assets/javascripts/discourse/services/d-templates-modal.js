import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service from "@ember/service";

export default class DTemplatesModalService extends Service {
  @tracked model = null;

  @action
  show(model) {
    this.model = model;
  }

  @action
  hide() {
    this.model?.editor?.focus();

    // clear the model
    this.model = null;
  }
}
