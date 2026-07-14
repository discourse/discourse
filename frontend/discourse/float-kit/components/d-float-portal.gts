import Component from "@glimmer/component";
import { isTesting } from "discourse/lib/environment";

interface DFloatPortalSignature {
  Args: {
    /** Whether to render in place instead of into the portal outlet. */
    inline?: boolean | null;

    /** The element to render into, instead of the default portal outlet. */
    portalOutletElement?: HTMLElement | null;
  };
  Blocks: {
    /** The content to portal. */
    default: [];
  };
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
