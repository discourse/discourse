// @ts-check
import Component from "@glimmer/component";
import isComponent from "discourse/lib/is-component";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
/** @type {import("./default-block-thumbnail.gjs").default} */
import DefaultBlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/default-block-thumbnail";

/**
 * Renders a palette tile's thumbnail, picking the right treatment for whatever
 * the block declared as its `thumbnail`. This is the single place that maps a
 * declared thumbnail to markup, so the sidebar tile and the hover preview can
 * never render it differently:
 *
 * - A component reference (an inline SVG component) is rendered inline, so it
 *   inherits theme color tokens and adapts to the active color scheme.
 * - A raster — either a single URL string or a `{ light, dark }` pair of URLs —
 *   is rendered through `DLightDarkImg`, which swaps per color scheme and falls
 *   back to the light image when no `dark` is supplied. This is the low-effort
 *   path: an author gets an (optionally adaptive) image without authoring a
 *   component.
 * - Nothing declared falls back to `DefaultBlockThumbnail` (a framed
 *   placeholder carrying the block's own icon).
 *
 * The consumer's `class` (which sizes the thumbnail box) is splatted through to
 * whichever element ends up rendering.
 *
 * @param {(string|{light: string, dark?: string}|Function|Object)} [thumbnail]
 *   The block's declared thumbnail (see above). Absent/`null` → default.
 * @param {string} icon - The block's icon ID, used by the default placeholder.
 */
export default class BlockThumbnail extends Component {
  /**
   * Whether the thumbnail is a component to render inline. Uses the core
   * `isComponent` helper to positively identify a real component (class or
   * template-only) rather than inferring it by elimination.
   *
   * @returns {boolean}
   */
  get isComponent() {
    return isComponent(this.args.thumbnail);
  }

  /**
   * Whether the thumbnail is a raster: a single URL string, or a plain object
   * carrying a `light` URL (with an optional `dark` counterpart). `light` is
   * required — `DLightDarkImg` renders nothing without it, so a `dark`-only
   * object is not a valid raster.
   *
   * @returns {boolean}
   */
  get isRaster() {
    const thumbnail = this.args.thumbnail;
    if (typeof thumbnail === "string") {
      return true;
    }
    return (
      typeof thumbnail === "object" &&
      thumbnail !== null &&
      "light" in thumbnail
    );
  }

  /**
   * The light image descriptor for `DLightDarkImg`, in its `{ url }` shape. A
   * bare string is treated as the light URL.
   *
   * @returns {{url: string}|undefined}
   */
  get lightImg() {
    const thumbnail = this.args.thumbnail;
    const url = typeof thumbnail === "string" ? thumbnail : thumbnail.light;
    return url ? { url } : undefined;
  }

  /**
   * The dark image descriptor for `DLightDarkImg`, or `undefined` when the
   * author supplied only a light image (a bare string, or a `{ light }` pair).
   *
   * @returns {{url: string}|undefined}
   */
  get darkImg() {
    const thumbnail = this.args.thumbnail;
    const dark = typeof thumbnail === "string" ? null : thumbnail.dark;
    return dark ? { url: dark } : undefined;
  }

  <template>
    {{#if this.isComponent}}
      <@thumbnail ...attributes />
    {{else if this.isRaster}}
      <DLightDarkImg
        @lightImg={{this.lightImg}}
        @darkImg={{this.darkImg}}
        ...attributes
      />
    {{else}}
      <DefaultBlockThumbnail @icon={{@icon}} ...attributes />
    {{/if}}
  </template>
}
