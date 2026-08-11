import Component from "@glimmer/component";
import { warn } from "@ember/debug";
import StyleguideExample from "./styleguide-example";

// Group ids are only unique within one manifest, so two sets of groups on a page could both
// hold a "start". A per-instance number keeps the heading ids distinct, which `aria-labelledby`
// depends on. A plain counter rather than `guidFor`: `@ember/object/internals` is not
// resolvable from a plugin bundle.
let groupId = 0;

/**
 * One group of a sectioned styleguide page. Renders its body only while it is the active group.
 *
 * Invoked through the curried component `StyleguideGroups` yields, so `@activeId` and `@groups`
 * are supplied for you and a call site passes only `@id`.
 *
 * Yields a `StyleguideExample` curried to `@headingLevel={{3}}`, so a grouped page keeps a
 * correct `h1` → `h2` → `h3` order without every call site restating the level. Ignoring the
 * block param and writing `<StyleguideExample>` directly still works, and renders `h2`.
 *
 * The `{{#if}}` is load-bearing and must NOT become a CSS-hidden variant: unmounting is what
 * tears down the group's live components, so each demo's own state is discarded when the reader
 * switches away rather than left running out of sight. Glimmer blocks are lazy, so an inactive
 * group's body is never instantiated in the first place.
 */
export default class StyleguideGroup extends Component {
  headingId = `styleguide-group-heading-${(groupId += 1)}`;

  constructor() {
    super(...arguments);

    // Guarded on the manifest rather than on `isActive`, and placed here rather than in a
    // getter: a mismatched id is exactly the case that can never be active, since `activeId`
    // only ever holds a manifest id, so an `isActive` guard would never fire and a getter
    // would repeat the warning on every render.
    warn(
      `<StyleguideGroup> was given @id="${this.args.id}", which no entry in the groups manifest declares. It can never become the active group, so its body will never render.`,
      this.record !== undefined,
      { id: "styleguide.group-id-not-in-manifest" }
    );
  }

  get isActive() {
    return this.args.id === this.args.activeId;
  }

  get record() {
    return (this.args.groups ?? []).find((group) => group.id === this.args.id);
  }

  <template>
    {{#if this.isActive}}
      <div
        class="styleguide-group"
        data-test-styleguide-group={{@id}}
        role="region"
        aria-labelledby={{this.headingId}}
        tabindex="-1"
      >
        <h2 class="styleguide-group__title" id={{this.headingId}}>
          {{this.record.title}}
        </h2>

        {{#if this.record.description}}
          <p class="styleguide-group__description">
            {{this.record.description}}
          </p>
        {{/if}}

        <div class="styleguide-group__examples">
          {{yield (component StyleguideExample headingLevel=3)}}
        </div>
      </div>
    {{/if}}
  </template>
}
