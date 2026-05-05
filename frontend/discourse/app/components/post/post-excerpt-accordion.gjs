import Component from "@glimmer/component";
import { fn } from "@ember/helper";
//import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import concatClass from "discourse/helpers/concat-class";
import PostExcerptAccordionItem from "./post-excerpt-accordion-item";

export default class PostExcerptAccordion extends Component {
  expandedIds = trackedSet();

  constructor() {
    super(...arguments);

    this.resetExpandedIds();
  }

  resetExpandedIds() {
    this.expandedIds.clear();

    const firstExcerptPostId = this.args.excerptPosts?.[0]?.id;
    if (firstExcerptPostId) {
      this.expandedIds.add(firstExcerptPostId);
    }
  }

  get topic() {
    return this.args.post.topic;
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
    <aside
      class={{concatClass "d-post-excerpt-accordion"}}
      data-topic={{@post.topic.id}}
      ...attributes
    >
      {{!-- <a {{on "click" this.toggleAllExpanded}}> --}}
      <div class="d-post-excerpt-accordion__header">
        {{#if (has-block "accordionHeader")}}
          {{yield this.excerptPosts to="accordionHeader"}}
        {{/if}}
      </div>
      {{! </a> }}

      {{#each this.excerptPosts as |excerptPost|}}
        <PostExcerptAccordionItem
          @decoratorState={{@decoratorState}}
          @excerptPost={{excerptPost}}
          @isExpanded={{this.itemIsExpanded excerptPost.id}}
          @onToggleExpanded={{fn this.toggleItemExpanded excerptPost.id}}
        >
          <:accordionItemMetadata>
            {{yield excerptPost to="accordionItemMetadata"}}
          </:accordionItemMetadata>

          <:accordionItemBeforeContent>
            {{yield excerptPost to="accordionItemBeforeContent"}}
          </:accordionItemBeforeContent>
        </PostExcerptAccordionItem>
      {{/each}}
    </aside>
  </template>
}
