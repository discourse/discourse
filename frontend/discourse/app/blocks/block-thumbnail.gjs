// @ts-check
import Component from "@glimmer/component";
import { TrackedAsyncData } from "ember-async-data";
import isComponent from "discourse/lib/is-component";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * A `TrackedAsyncData` per lazy loader, so a lazily-loaded thumbnail is fetched
 * at most once across the whole app. `DAsyncContent` builds a fresh
 * `TrackedAsyncData` per instance, which would re-enter the loading state every
 * time the component remounts; caching it here and handing the same (already-resolved)
 * instance to `DAsyncContent` makes every later render report `content`
 * immediately — no loading flash. Keyed by the loader function reference, which
 * is stable (it lives in the frozen `@block` metadata).
 *
 * @type {Map<Function, InstanceType<typeof TrackedAsyncData>>}
 */
const thumbnailDataByLoader = new Map();

/**
 * The terminal placeholder shown when there is no thumbnail to render — either
 * nothing was declared, or a lazy loader rejected. Prefers a caller-supplied
 * `@fallback` component (so a consumer can dress the placeholder however it
 * likes) and otherwise renders the block's own icon. The consumer's
 * `...attributes` (e.g. a sizing class) are forwarded to whichever wins.
 *
 * @param {Function} [fallback] - A component rendered instead of the bare icon.
 * @param {string} icon - The block's icon ID, passed to the fallback and used
 *   for the bare-icon default.
 */
const ThumbnailPlaceholder = <template>
  {{#if @fallback}}
    <@fallback @icon={{@icon}} ...attributes />
  {{else}}
    <span class="block-thumbnail__icon" ...attributes>{{dIcon @icon}}</span>
  {{/if}}
</template>;

/**
 * Renders a block's declared `thumbnail`, mapping whichever form the block
 * declared to markup. This is the single place that turns a declared thumbnail
 * into pixels, so every consumer renders it identically and none has to branch
 * on the form or deal with the lazy loader's promise itself:
 *
 * - A component reference (an inline SVG component) is rendered inline, so it
 *   inherits theme color tokens and adapts to the active color scheme.
 * - A loader that resolves to such a component (a lazily-loaded thumbnail, e.g.
 *   `() => import("...")`) is awaited here, once per loader: a skeleton shows
 *   while it loads the first time, the resolved component renders once ready,
 *   and the placeholder shows if it fails. Because the resolution is cached
 *   module-wide, later renders of the same thumbnail render synchronously with
 *   no loading state. The loader may resolve to the component directly or to a
 *   module whose `default` export is the component.
 * - A raster — either a single URL string or a `{ light, dark }` pair of URLs —
 *   is rendered through `DLightDarkImg`, which swaps per color scheme and falls
 *   back to the light image when no `dark` is supplied. This is the low-effort
 *   path: a consumer gets an (optionally adaptive) image without authoring a
 *   component.
 * - Nothing declared renders the placeholder (a `@fallback` component if given,
 *   otherwise the block's own icon).
 *
 * The consumer's `...attributes` (which typically size the thumbnail box) are
 * forwarded to whichever element ends up rendering.
 *
 * @param {(string|{light: string, dark?: string}|Function|Object)} [thumbnail]
 *   The block's declared thumbnail (see above). Absent/`null` → placeholder.
 * @param {string} icon - The block's icon ID, used by the placeholder.
 * @param {Function} [fallback] - A component rendered for the placeholder
 *   (nothing-declared or load-error) instead of the bare icon.
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
   * Whether the thumbnail is a loader that resolves to a component (a
   * lazily-loaded thumbnail, e.g. `() => import("...")`). A component class is
   * itself a function, so a lazy loader is any function that is not already a
   * renderable component.
   *
   * @returns {boolean}
   */
  get isLazyComponent() {
    return typeof this.args.thumbnail === "function" && !this.isComponent;
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
   * consumer supplied only a light image (a bare string, or a `{ light }` pair).
   *
   * @returns {{url: string}|undefined}
   */
  get darkImg() {
    const thumbnail = this.args.thumbnail;
    const dark = typeof thumbnail === "string" ? null : thumbnail.dark;
    return dark ? { url: dark } : undefined;
  }

  /**
   * The cached `TrackedAsyncData` for the lazy loader, created (and the load
   * kicked off) once per loader. Handed to `DAsyncContent`, which renders the
   * loading, resolved, and error states from it. Because the same instance is
   * reused across mounts, a thumbnail that already resolved reports `content`
   * immediately on later renders — no repeated loading state. The loader may
   * resolve to the component directly or to a module whose `default` export is
   * the component, so both shapes are unwrapped.
   *
   * @returns {InstanceType<typeof TrackedAsyncData>} The resolution state.
   */
  get thumbnailData() {
    const loader = this.args.thumbnail;
    let data = thumbnailDataByLoader.get(loader);
    if (!data) {
      const promise = Promise.resolve(loader()).then(
        (resolved) => resolved?.default ?? resolved
      );
      // `TrackedAsyncData` handles rejection internally and registers its own
      // test waiter, so tests wait for the load to settle.
      data = new TrackedAsyncData(promise);
      thumbnailDataByLoader.set(loader, data);
    }
    return data;
  }

  <template>
    {{#if this.isRaster}}
      <DLightDarkImg
        @lightImg={{this.lightImg}}
        @darkImg={{this.darkImg}}
        ...attributes
      />
    {{else if this.isComponent}}
      <@thumbnail ...attributes />
    {{else if this.isLazyComponent}}
      <DAsyncContent @asyncData={{this.thumbnailData}}>
        <:loading>
          <DSkeleton
            @variant="rect"
            class="block-thumbnail__skeleton"
            ...attributes
          />
        </:loading>
        <:content as |ResolvedThumbnail|>
          <ResolvedThumbnail ...attributes />
        </:content>
        <:error>
          <ThumbnailPlaceholder
            @fallback={{@fallback}}
            @icon={{@icon}}
            ...attributes
          />
        </:error>
      </DAsyncContent>
    {{else}}
      <ThumbnailPlaceholder
        @fallback={{@fallback}}
        @icon={{@icon}}
        ...attributes
      />
    {{/if}}
  </template>
}
