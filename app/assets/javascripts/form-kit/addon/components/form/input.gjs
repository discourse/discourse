import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import Node from "form-kit/lib/node";

export default class FormInput extends Component {
  node = new Node(
    {
      type: "input",
      value: this.args.value,
      name: this.args.name,
      parent: this.args.node,
    },
    {
      validation: this.args.validation,
      optional: this.args.optional,
      horizontal: this.args.horizontal,
      type: this.args.type,
      id: this.args.id,
      placeholder: this.args.placeholder,
    }
  );

  constructor() {
    super(...arguments);

    next(() => {
      this.args.node.add(this.node);

      this.node.validate();
    });
  }

  @action
  onInput(event) {
    this.node.input(event.target.value);
    this.node.validate();
  }

  <template>
    <Input
      id={{this.node.props.id}}
      type={{this.node.props.type}}
      @value={{readonly this.node.config.value}}
      name={{this.node.config.name}}
      class="d-form-field__input"
      {{on "input" this.onInput}}
      placeholder={{this.node.props.placeholder}}
      ...attributes
    />
  </template>
}
