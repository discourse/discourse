import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";

export default class Label extends Component {
  get size() {
    return this.args.node.context.horizontal ? 2 : null;
  }

  <template>
    <label
      class={{concatClass
        "d-form-field__label"
        (if this.size (concat "--col-" this.size))
      }}
      for={{@node.config.name}}
    >
      {{@node.props.label}}
      {{#if @node.props.optional}}
        <span class="d-form-field__optional">(Optional)</span>
      {{/if}}
    </label>
  </template>
}
