import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { trackedSet } from "@ember/reactive/collections";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DPostAccordionItem, {
  type DPostAccordionPost,
} from "./d-post-accordion-item.gts";

interface DPostAccordionSignature {
  Args: {
    /** The posts to show. Without any, nothing is rendered. */
    posts?: DPostAccordionPost[] | null;

    /** Which posts start expanded. Defaults to the first one. */
    defaultExpanded?: "all" | "none" | "first" | "";

    /** How many lines of a collapsed post to show. */
    linesDisplayed?: number | string;

    /** State passed to the post decorators. */
    decoratorState?: unknown;
  };

  Element: HTMLElement;

  Blocks: {
    /** A header above the posts. */
    header: [posts: DPostAccordionPost[]];

    /** The metadata of a post, in place of its author and date. */
    itemMetadata: [post: DPostAccordionPost];

    /** Content shown before a post's content. */
    beforeItemContent: [post: DPostAccordionPost];
  };
}

export default class DPostAccordion extends Component<DPostAccordionSignature> {
  expandedIds = trackedSet<number>();

  constructor(owner: Owner, args: DPostAccordionSignature["Args"]) {
    super(owner, args);

    this.resetExpandedIds();
  }

  get posts() {
    return this.args.posts ?? [];
  }

  get allExpanded() {
    return this.posts.every((post) => this.expandedIds.has(post.id));
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

  @action
  toggleAllExpanded() {
    if (this.allExpanded) {
      this.resetExpandedIds();
    } else {
      this.posts.forEach((post) => this.expandedIds.add(post.id));
    }
  }

  @action
  toggleItemExpanded(postId: number) {
    this.expandedIds.has(postId)
      ? this.expandedIds.delete(postId)
      : this.expandedIds.add(postId);
  }

  @action
  itemIsExpanded(postId: number) {
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
                @hasBeforeItemContentBlock={{has-block "beforeItemContent"}}
                @hasItemMetadataBlock={{has-block "itemMetadata"}}
                @isExpanded={{this.itemIsExpanded post.id}}
                @linesDisplayed={{@linesDisplayed}}
                @onToggleExpanded={{fn this.toggleItemExpanded post.id}}
                @post={{post}}
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
