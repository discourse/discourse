import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import type Store from "discourse/services/store";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";

/** The `tag-info` record fields the banner reads. */
interface TagInfo {
  description?: string;
}

interface TagBannerSignature {
  Args: {
    showDescription?: boolean;
  };
}

/**
 * Tag-page banner showing the current tag, with an optional description. Reads
 * the tag from the router's current-route params (`tag_id`) and renders nothing
 * outside tag routes — the route-driven sibling of `category-banner`, so the
 * block can be dropped on a general outlet and stay invisible elsewhere. The tag
 * name comes straight from the route; the description (when enabled) is fetched
 * lazily from the `tag-info` endpoint.
 */
@block("tag-banner", {
  thumbnail: () => import("discourse/blocks/thumbnails/tag-banner"),
  displayName: "Tag banner",
  icon: "tag",
  category: "Discourse data",
  description: "Banner for the current tag page showing the tag.",
  args: {
    showDescription: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.tag_banner.show_description"),
      },
    },
  },
})
export default class TagBanner extends Component<TagBannerSignature> {
  @service declare router: RouterService;
  @service declare store: Store;

  /**
   * The `tag-info` record for the current tag, or `null` until it resolves.
   * Holds the description text the banner renders when `showDescription` is on.
   */
  @tracked tagInfo: TagInfo | null = null;

  /**
   * The current tag's display name from the route params, or `undefined` off a
   * tag route. The canonical tag route (`/tag/:tag_slug/:tag_id`) carries the
   * human tag name in `tag_slug` — `tag_id` there is the numeric record id, so
   * displaying it would show a number instead of the tag. Fall back to `tag_id`
   * for any single-segment tag route that carries the name in that param.
   *
   * @returns The current tag's display name, or `undefined` off a tag route.
   */
  get tagName() {
    const params: Record<string, unknown> =
      this.router?.currentRoute?.params ?? {};
    return (params.tag_slug ?? params.tag_id) as string | undefined;
  }

  /**
   * Whether the banner should render at all.
   *
   * @returns Whether the current route is a tag route with a resolved name.
   */
  get shouldRender() {
    const name = this.router?.currentRoute?.name ?? "";
    return name.startsWith("tag.") && !!this.tagName;
  }

  /**
   * Whether the description region should appear. Honours the `showDescription`
   * arg and collapses when the resolved tag carries no description text.
   *
   * @returns Whether the description region should render.
   */
  get displayDescription() {
    return this.args.showDescription && this.tagInfo?.description?.length > 0;
  }

  /**
   * Resolves the current tag's `tag-info` record so the description is
   * available. Triggered by `did-insert` / `did-update` so it refreshes on every
   * tag-route change. Skips the fetch entirely when the description is disabled.
   */
  @action
  async loadTagInfo() {
    if (!this.shouldRender || !this.args.showDescription) {
      this.tagInfo = null;
      return;
    }

    try {
      this.tagInfo = await this.store.find("tag-info", this.tagName);
    } catch {
      this.tagInfo = null;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div
        class="d-block-tag-banner"
        {{didInsert this.loadTagInfo}}
        {{didUpdate this.loadTagInfo this.tagName @showDescription}}
      >
        <h2 class="d-block-tag-banner__title">{{dDiscourseTag
            this.tagName
          }}</h2>

        {{#if this.displayDescription}}
          <p class="d-block-tag-banner__description">
            {{this.tagInfo.description}}
          </p>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
