import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class FKAlert extends Component {
  get type() {
    return this.args.type || "info";
  }

  <template>
    <div class="form-kit__alert alert alert-{{this.type}}" ...attributes>
      {{#if @icon}}
        {{dIcon @icon}}
      {{/if}}

      <span class="form-kit__alert-message">{{yield}}</span>
    </div>
  </template>
}
