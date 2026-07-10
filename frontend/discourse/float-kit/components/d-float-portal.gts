import Component from "@glimmer/component";
import { isTesting } from "discourse/lib/environment";

interface DFloatPortalSignature {
  Args: {
    inline?: boolean | null;
    portalOutletElement?: HTMLElement | null;
  };
  Blocks: { default: [] };
}

export default class DFloatPortal extends Component<DFloatPortalSignature> {
  get inline() {
    return this.args.inline ?? isTesting();
  }

  <template>
    {{~#if this.inline}}
      {{yield}}
    {{else}}
      {{#in-element @portalOutletElement insertBefore=null}}
        {{yield}}
      {{/in-element}}
    {{/if~}}
  </template>
}
