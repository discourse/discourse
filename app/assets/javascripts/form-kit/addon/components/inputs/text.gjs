import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import Node from "form-kit/lib/node";
import concatClass from "discourse/helpers/concat-class";
import Label from "../label";
import Meta from "../meta";

export default class Text extends Component {
  node = new Node(
    {
      type: "input",
      value: this.args.value,
      name: this.args.name,
      parent: this.args.node,
    },
    { label: this.args.label, help: this.args.help }
  );

  constructor() {
    super(...arguments);

    next(() => {
      this.args.node.add(this.node);

      console.log(this.args.node);
    });
  }

  @action
  onInput(event) {
    this.node.input(event.target.value);
    this.node.validate();
  }

  <template>
    {{log this.node.props}}
    <div
      class={{concatClass "d-form-field" (unless this.node.valid "has-error")}}
    >
      {{#if this.node.props.label}}
        <Label
          @label={{this.node.props.label}}
          @for={{this.node.config.name}}
        />
      {{/if}}

      <Input
        @type="text"
        @value={{readonly this.node.config.value}}
        name={{this.node.config.name}}
        class="d-form-field__input"
        {{on "input" this.onInput}}
        ...attributes
      />

      <Meta @node={{this.node}} />
    </div>
  </template>
}
