import Component from "@glimmer/component";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import AiSearchTopicRow from "./ai-search-topic-row.gjs";

export default class AiSearchReferencesPanel extends Component {
  @service site;

  get references() {
    return (this.args.references || []).map((reference) => ({
      ...reference,
      category: this.site.categories?.find(
        (category) => category.id === reference.categoryId
      ),
    }));
  }

  <template>
    <aside
      aria-labelledby="ai-search-references-title"
      class="ai-search-references"
      ...attributes
    >
      <h3 class="ai-search-references__title" id="ai-search-references-title">
        {{i18n "discourse_ai.ai_search.references_title"}}
      </h3>

      <ol class="ai-search-references__list">
        {{#each this.references key="topicId" as |reference|}}
          <li
            class={{dConcatClass
              "ai-search-references__item"
              (if reference.isNew "--new")
              (if (gt reference.movement 0) "--up")
            }}
          >
            <AiSearchTopicRow
              class="ai-search-references__link"
              @bumpedAt={{reference.bumpedAt}}
              @category={{reference.category}}
              @replyCount={{reference.replyCount}}
              @title={{reference.title}}
              @url={{reference.url}}
            />
          </li>
        {{else}}
          <li class="ai-search-references__empty">
            {{i18n "discourse_ai.ai_search.references_empty"}}
          </li>
        {{/each}}
      </ol>
    </aside>
  </template>
}
