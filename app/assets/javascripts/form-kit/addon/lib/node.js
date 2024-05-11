import { tracked } from "@glimmer/tracking";
import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import Validator from "form-kit/lib/validator";

export default class Node {
  @tracked config = new TrackedObject();
  @tracked props = new TrackedObject();
  @tracked children = new TrackedArray();
  @tracked valid = true;
  @tracked validationMessages = new TrackedArray();

  constructor(config = {}, props = {}) {
    config.type ??= "input";
    this.config = new TrackedObject(config);
    this.props = new TrackedObject(props);
  }

  get allValidationMessages() {
    const messages = [...this.validationMessages];

    this.children.forEach((child) => {
      messages.push(...child.validationMessages);
    });

    return messages;
  }

  add(node) {
    this.children.push(node);
  }

  async input(value) {
    this.config.value = value;
  }

  async validate() {
    const validator = new Validator();
    await validator.validate(this);

    console.log(validator);
  }
}
