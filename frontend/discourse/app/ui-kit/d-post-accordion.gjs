import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DPostAccordionItem from "./d-post-accordion-item";

export default class DPostAccordion extends Component {
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
        this.posts.forEach((post) => this.expandedIds.add(post.id));
        break;
      case "none":
        break;
      case "first":
      case "":
      default:
        const firstPostId = this.args.posts?.[0]?.id;
        if (firstPostId) {
          this.expandedIds.add(firstPostId);
        }
    }
  }

  get posts() {
    return this.args.posts ?? [];
  }

  get allExpanded() {
    return this.posts.every((post) => this.expandedIds.has(post.id));
  }

  @action
  toggleAllExpanded() {
    if (this.allExpanded) {
      this.resetExpandedIds();
    } else {
      this.posts.forEach((post) => this.expandedIds.add(post.id));
    }
  }

  @action
  toggleItemExpanded(postId) {
    this.expandedIds.has(postId)
      ? this.expandedIds.delete(postId)
      : this.expandedIds.add(postId);
  }

  @action
  itemIsExpanded(postId) {
    return this.expandedIds.has(postId);
  }

  <template>
    {{#if this.posts.length}}
      <aside
        class="d-post-accordion"
        ...attributes
        {{didUpdate this.resetExpandedIds this.posts}}
      >
        <div class="d-post-accordion__layout">
          <div class="d-post-accordion__header">
            {{#if (has-block "header")}}
              {{yield this.posts to="header"}}
            {{/if}}
          </div>

          <div class="d-post-accordion__items">
            {{#each this.posts as |post|}}
              <DPostAccordionItem
                @decoratorState={{@decoratorState}}
                @post={{post}}
                @isExpanded={{this.itemIsExpanded post.id}}
                @onToggleExpanded={{fn this.toggleItemExpanded post.id}}
                @linesDisplayed={{@linesDisplayed}}
                @hasItemMetadataBlock={{has-block "itemMetadata"}}
                @hasBeforeItemContentBlock={{has-block "beforeItemContent"}}
              >

                <:itemMetadata>
                  {{yield post to="itemMetadata"}}
                </:itemMetadata>

                <:beforeItemContent>
                  {{yield post to="beforeItemContent"}}
                </:beforeItemContent>
              </DPostAccordionItem>
            {{/each}}
          </div>
        </div>
      </aside>
    {{/if}}
  </template>
}
