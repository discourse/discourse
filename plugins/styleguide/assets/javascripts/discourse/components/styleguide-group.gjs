import Component from "@glimmer/component";

/**
 * One group of a sectioned styleguide page. Renders its body only while it is the active group.
 *
 * Invoked through the curried component `StyleguideGroups` yields, so `@activeId` and `@groups`
 * are supplied for you and a call site passes only `@id`. The heading and description are read
 * from the manifest rather than repeated here, keeping one source of truth for group titles.
 *
 * The `{{#if}}` is load-bearing and must NOT become a CSS-hidden variant: unmounting is what
 * tears down the group's live components, so per-example counters and in-flight sources reset
 * when the reader switches away. Glimmer blocks are lazy, so an inactive group's body is never
 * instantiated in the first place.
 */
export default class StyleguideGroup extends Component {
  get isActive() {
    return this.args.id === this.args.activeId;
  }

  get record() {
    return (this.args.groups ?? []).find((group) => group.id === this.args.id);
  }

  get headingId() {
    return `styleguide-group-heading-${this.args.id}`;
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
          {{yield}}
        </div>
      </div>
    {{/if}}
  </template>
}
