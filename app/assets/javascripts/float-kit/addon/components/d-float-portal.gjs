import Component from "@glimmer/component";
import { isTesting } from "discourse-common/config/environment";

export default class DFloatPortal extends Component {
  get inline() {
    return this.args.inline ?? isTesting();
  }

  <template>
    {{#if this.inline}}
      {{yield}}
    {{else}}
      {{#in-element @portalOutletElement insertBefore=null}}
        {{yield}}
      {{/in-element}}
    {{/if}}
  </template>
}
