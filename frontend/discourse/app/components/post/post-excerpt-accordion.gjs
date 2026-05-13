import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import PostExcerptAccordionItem from "./post-excerpt-accordion-item";

export default class PostExcerptAccordion extends Component {
  expandedIds = trackedSet();

  constructor() {
    super(...arguments);

    this.resetExpandedIds();
  }

  @action
  resetExpandedIds() {
    const defaultExpanded = this.args.defaultExpanded;

    this.expandedIds.clear();

    switch (defaultExpanded) {
      case "all":
        this.excerptPosts.forEach((excerptPost) =>
          this.expandedIds.add(excerptPost.id)
        );
        break;
      case "none":
        break;
      case "first":
      case "":
      default:
        const firstExcerptPostId = this.args.excerptPosts?.[0]?.id;
        if (firstExcerptPostId) {
          this.expandedIds.add(firstExcerptPostId);
        }
    }
  }

  get excerptPosts() {
    return this.args.excerptPosts ?? [];
  }

  get allExpanded() {
    return this.excerptPosts.every((excerptPost) =>
      this.expandedIds.has(excerptPost.id)
    );
  }

  @action
  toggleAllExpanded() {
    if (this.allExpanded) {
      this.resetExpandedIds();
    } else {
      this.excerptPosts.forEach((excerptPost) =>
        this.expandedIds.add(excerptPost.id)
      );
    }
  }

  @action
  toggleItemExpanded(excerptPostId) {
    this.expandedIds.has(excerptPostId)
      ? this.expandedIds.delete(excerptPostId)
      : this.expandedIds.add(excerptPostId);
  }

  @action
  itemIsExpanded(excerptPostId) {
    return this.expandedIds.has(excerptPostId);
  }

  <template>
    {{#if this.excerptPosts.length}}
      <aside
        class={{dConcatClass "d-post-excerpt-accordion"}}
        ...attributes
        {{didUpdate this.resetExpandedIds this.excerptPosts}}
      >
        <div class="d-post-excerpt-accordion__header">
          {{#if (has-block "header")}}
            {{yield this.excerptPosts to="header"}}
          {{/if}}
        </div>

        {{#each this.excerptPosts as |excerptPost|}}
          <PostExcerptAccordionItem
            @decoratorState={{@decoratorState}}
            @excerptPost={{excerptPost}}
            @isExpanded={{this.itemIsExpanded excerptPost.id}}
            @onToggleExpanded={{fn this.toggleItemExpanded excerptPost.id}}
            @linesDisplayed={{@linesDisplayed}}
            @defaultExpanded="first"
            @hasItemMetadataBlock={{has-block "itemMetadata"}}
            @hasBeforeItemContentBlock={{has-block "beforeItemContent"}}
          >

            <:itemMetadata>
              {{yield excerptPost to="itemMetadata"}}
            </:itemMetadata>

            <:beforeItemContent>
              {{yield excerptPost to="beforeItemContent"}}
            </:beforeItemContent>
          </PostExcerptAccordionItem>
        {{/each}}
      </aside>
    {{/if}}
  </template>
}
