// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";

/**
 * Tag-page banner showing the current tag. Reads the tag from the router's
 * current-route params (`tag_id`) and renders nothing outside tag routes —
 * the route-driven sibling of `category-banner`, so the block can be dropped
 * on a general outlet and stay invisible elsewhere. No data hook: the tag
 * name comes straight from the route.
 */
@block("tag-banner", {
  displayName: "Tag banner",
  icon: "tag",
  category: "Discourse data",
  description: "Banner for the current tag page showing the tag.",
})
export default class TagBanner extends Component {
  @service router;

  /**
   * The current tag's display name from the route params, or `undefined` off a
   * tag route. The canonical tag route (`/tag/:tag_slug/:tag_id`) carries the
   * human tag name in `tag_slug` — `tag_id` there is the numeric record id, so
   * displaying it would show a number instead of the tag. Fall back to `tag_id`
   * for any single-segment tag route that carries the name in that param.
   *
   * @returns {string|undefined}
   */
  get tagName() {
    const params = this.router?.currentRoute?.params ?? {};
    return params.tag_slug ?? params.tag_id;
  }

  /** @returns {boolean} Whether the banner should render at all. */
  get shouldRender() {
    const name = this.router?.currentRoute?.name ?? "";
    return name.startsWith("tag.") && !!this.tagName;
  }

  <template>
    {{#if this.shouldRender}}
      <div class="d-block-tag-banner">
        <h2 class="d-block-tag-banner__title">{{dDiscourseTag
            this.tagName
          }}</h2>
      </div>
    {{/if}}
  </template>
}
