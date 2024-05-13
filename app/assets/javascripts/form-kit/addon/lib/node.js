import { tracked } from "@glimmer/tracking";
import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import Validator from "form-kit/lib/validator";
import Context from "./context";
import Rules from "./rules";

export default class Node {
  @tracked children = new TrackedArray();
  @tracked valid = true;
  @tracked validationMessages = new TrackedArray();
  @tracked config;
  @tracked props;

  @tracked parent;

  constructor(config = {}, props = {}) {
    config.type ??= "input";
    this.config = new TrackedObject(config);
    this.props = new TrackedObject(props);
    this.rules = Rules.parse(this.props.validation);
    this.context = new Context(this);
  }

  get allValidationMessages() {
    const messages = [...this.validationMessages];

    this.children.forEach((child) => {
      messages.push(...child.validationMessages);
    });

    return messages;
  }

  add(node) {
    node.parent = this;
    this.children.push(node);
  }

  async input(value) {
    this.config.value = value;
  }

  async validate() {
    const validator = new Validator();
    await validator.validate(this);
  }
}
