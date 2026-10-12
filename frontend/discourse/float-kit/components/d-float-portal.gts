import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { isTesting } from "discourse/lib/environment";

interface DFloatPortalSignature {
  Args: {
    /** Whether to render in place instead of into the portal outlet. */
    inline?: boolean | null;

    /** The element to render into, instead of the default portal outlet. */
    portalOutletElement?: HTMLElement | null;
  };
  Blocks: {
    /** The content to render in place or teleport into the portal outlet. */
    default: [];
  };
}

/**
 * The lowest-level teleport primitive shared by every float. It either renders
 * its content in place or moves it (via `{{in-element}}`) into a portal outlet
 * mounted near the document root, so the content escapes any `overflow` clipping
 * or stacking context of its trigger. Rendering is forced in place under tests,
 * where there is no portal outlet to teleport into.
 */
export default class DFloatPortal extends Component<DFloatPortalSignature> {
  get inline() {
    return this.args.inline ?? isTesting();
  }

  /** The outlet to teleport into. A missing one means the portal container is not on the page. */
  get portalOutlet(): HTMLElement {
    const outlet = this.args.portalOutletElement;
    assert("DFloatPortal: the portal outlet is missing from the page", outlet);
    return outlet;
  }

  <template>
    {{~#if this.inline}}
      {{yield}}
    {{else}}
      {{#in-element this.portalOutlet insertBefore=null}}
        {{yield}}
      {{/in-element}}
    {{/if~}}
  </template>
}
