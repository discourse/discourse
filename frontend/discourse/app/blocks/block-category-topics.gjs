import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { block } from "discourse/blocks";
import CategoryTitleLink from "discourse/components/category-title-link";
import replaceEmoji from "discourse/helpers/replace-emoji";
import Category from "discourse/models/category";

@block("category-topics")
export default class BlockCategoryTopics extends Component {
  @service store;

  @tracked topics = null;
  @tracked category = null;

  <template>
    {{#if this.topics}}
      <div class="block-category-topics__layout">
        <div class="block-category-topics__link">
          <CategoryTitleLink @category={{this.category}} />
        </div>

        <div class="block-category-topics__list">
          {{#each this.topics as |topic|}}
            <a href={{topic.url}} class="block-category-topics__topic">
              {{htmlSafe (replaceEmoji topic.fancy_title)}}
              <span class="block-category-topics__post-count">
                ({{topic.posts_count}})
              </span>
            </a>
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>

  constructor() {
    super(...arguments);
    const count = this.args.count || 10;
    const categoryId = this.args.categoryId;

    if (!categoryId) {
      return;
    }

    const filter = "c/" + categoryId;
    this.category = Category.findById(categoryId);

    this.store.findFiltered("topicList", { filter }).then((topicList) => {
      if (topicList.topics) {
        this.topics = topicList.topics.slice(0, count);
      }
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.topics = null;
  }
}
