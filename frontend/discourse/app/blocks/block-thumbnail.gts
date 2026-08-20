import Component from "@glimmer/component";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { service } from "@ember/service";
import type { ComponentLike } from "@glint/template";
import type { TrackedAsyncData } from "ember-async-data";
import type { BlockThumbnail as ThumbnailValue } from "discourse/blocks/types";
import isComponent from "discourse/lib/is-component";
import type BlocksService from "discourse/services/blocks";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DLightDarkImg from "discourse/ui-kit/d-light-dark-img";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * A caller-supplied component rendered in place of the bare block icon in the
 * placeholder. It receives the block's icon ID and forwards the consumer's
 * `...attributes`.
 */
type ThumbnailFallback = ComponentLike<{
  Args: { icon: string };
  Element: HTMLElement;
}>;

/**
 * A thumbnail rendered as an inline component (an inline SVG component, or the
 * component a lazy loader resolves to). It takes no args and is sized by the
 * forwarded `...attributes`.
 */
type ThumbnailComponent = ComponentLike<{ Element: HTMLElement }>;

/** The light/dark raster shape a block may declare as its thumbnail. */
type ThumbnailRaster = { light: string; dark?: string };

interface ThumbnailPlaceholderSignature {
  Args: {
    /** An optional component rendered instead of the bare icon. */
    fallback?: ThumbnailFallback;
    /** The block's icon ID, passed to the fallback and used for the default. */
    icon: string;
  };
  Element: HTMLElement;
}

/**
 * The terminal placeholder shown when there is no thumbnail to render — either
 * nothing was declared, or a lazy loader rejected. Prefers a caller-supplied
 * `@fallback` component (so a consumer can dress the placeholder however it
 * likes) and otherwise renders the block's own icon. The consumer's
 * `...attributes` (e.g. a sizing class) are forwarded to whichever wins.
 */
const ThumbnailPlaceholder: TemplateOnlyComponent<ThumbnailPlaceholderSignature> =
  <template>
    {{#if @fallback}}
      <@fallback @icon={{@icon}} ...attributes />
    {{else}}
      <span class="block-thumbnail__icon" ...attributes>{{dIcon @icon}}</span>
    {{/if}}
  </template>;

interface BlockThumbnailSignature {
  Args: {
    /**
     * The block's declared thumbnail: a URL string, a light/dark URL pair, a
     * component, or a lazy loader resolving to one (see {@link ThumbnailValue}).
     * Absent or `null` renders the placeholder. This is a runtime-discriminated
     * polymorphic value that the getters below narrow.
     */
    thumbnail?: ThumbnailValue;
    /** The block's icon ID, used by the placeholder. */
    icon: string;
    /**
     * An optional component rendered for the placeholder instead of the bare
     * icon.
     */
    fallback?: ThumbnailFallback;
  };
  Element: HTMLElement;
}

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
 */
export default class BlockThumbnail extends Component<BlockThumbnailSignature> {
  @service declare blocks: BlocksService;

  /**
   * Whether the thumbnail is a component to render inline. Uses the core
   * `isComponent` helper to positively identify a real component (class or
   * template-only) rather than inferring it by elimination.
   */
  get isComponent(): boolean {
    return isComponent(this.args.thumbnail);
  }

  /**
   * Whether the thumbnail is a loader that resolves to a component (a
   * lazily-loaded thumbnail, e.g. `() => import("...")`). A component class is
   * itself a function, so a lazy loader is any function that is not already a
   * renderable component.
   */
  get isLazyComponent(): boolean {
    return typeof this.args.thumbnail === "function" && !this.isComponent;
  }

  /**
   * Whether the thumbnail is a raster: a single URL string, or a plain object
   * carrying a `light` URL (with an optional `dark` counterpart). `light` is
   * required — `DLightDarkImg` renders nothing without it, so a `dark`-only
   * object is not a valid raster.
   */
  get isRaster(): boolean {
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
   */
  get lightImg(): { url: string } | undefined {
    const thumbnail = this.args.thumbnail;
    // Callers reach this getter under the `isRaster` guard, so in the non-string
    // branch the value is the light/dark raster object; narrow to it explicitly.
    const url =
      typeof thumbnail === "string"
        ? thumbnail
        : (thumbnail as ThumbnailRaster).light;
    return url ? { url } : undefined;
  }

  /**
   * The dark image descriptor for `DLightDarkImg`, or `undefined` when the
   * consumer supplied only a light image (a bare string, or a `{ light }` pair).
   */
  get darkImg(): { url: string } | undefined {
    const thumbnail = this.args.thumbnail;
    // As with `lightImg`, the non-string branch is the raster object here.
    const dark =
      typeof thumbnail === "string"
        ? null
        : (thumbnail as ThumbnailRaster).dark;
    return dark ? { url: dark } : undefined;
  }

  /**
   * The `TrackedAsyncData` for the lazy loader, resolved and cached by the
   * `blocks` service (so each loader is fetched at most once app-wide and can be
   * prefetched). Handed to `DAsyncContent`, which renders the loading, resolved,
   * and error states from it; an already-resolved loader reports `content`
   * immediately, so no loading state re-shows on later renders.
   *
   * The service caches by loader identity and cannot know each loader's own
   * resolved type, so it hands back `TrackedAsyncData<unknown>`; this getter is
   * only reached under the `isLazyComponent` guard, where the resolved value is
   * a renderable component, so its resolution is projected to that type.
   *
   * @returns The resolution state, resolving to the loaded thumbnail component.
   */
  get thumbnailData(): TrackedAsyncData<ThumbnailComponent> {
    return this.blocks.thumbnailData(
      this.args.thumbnail
    ) as TrackedAsyncData<ThumbnailComponent>;
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
