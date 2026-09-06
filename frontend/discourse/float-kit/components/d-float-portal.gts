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
