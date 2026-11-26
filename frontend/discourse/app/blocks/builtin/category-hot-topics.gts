import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import TopicLink from "discourse/components/topic-list/topic-link";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import type StoreService from "discourse/services/store";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import { i18n } from "discourse-i18n";

interface CategoryHotTopicsSignature {
  Args: {
    outletArgs?: { category?: Category };
  };
}

@block("category-hot-topics", {
  description: "Hot topics in the category passed to the outlet",
})
export default class CategoryHotTopics extends Component<CategoryHotTopicsSignature> {
  @service declare store: StoreService;

  @bind
  async fetchTopics(category: unknown) {
    if (!(category instanceof Category)) {
      return null;
    }

    const filter = `c/${Category.slugFor(category)}/${category.id}/none/l/hot`;
    const list = await this.store.findFiltered("topicList", { filter });
    const topics = list.topics?.filter((topic) => !topic.pinned).slice(0, 5);
    return topics?.length ? topics : null;
  }

  <template>
    {{#if @outletArgs.category}}
      <section class="context-category__block">
        <h3>{{i18n "page_shell.category_hot_topics"}}</h3>
        <DAsyncContent
          @asyncData={{this.fetchTopics}}
          @context={{@outletArgs.category}}
        >
          <:loading><DSkeleton @count={{5}} /></:loading>
          <:content as |topics|>
            <ul class="context-category__topics">
              {{#each topics as |topic|}}
                <li><TopicLink @topic={{topic}} /></li>
              {{/each}}
            </ul>
          </:content>
          <:empty><p>{{i18n
                "page_shell.category_hot_topics_empty"
              }}</p></:empty>
        </DAsyncContent>
      </section>
    {{/if}}
  </template>
}
