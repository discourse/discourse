import Component from "@glimmer/component";
import { service } from "@ember/service";
import { gt, lt } from "discourse/truth-helpers";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

export default class AiSearchReferencesPanel extends Component {
  @service site;

  get references() {
    return (this.args.references || []).map((reference) => ({
      ...reference,
      category: this.site.categories?.find(
        (category) => category.id === reference.categoryId
      ),
      movedBy: Math.abs(reference.movement),
      kindLabels: reference.kinds.map((kind) => ({
        kind,
        label: i18n(`discourse_ai.ai_search.reference_kinds.${kind}`),
      })),
    }));
  }

  <template>
    <aside
      aria-labelledby="ai-search-references-title"
      class="ai-search-references"
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
              (if (lt reference.movement 0) "--down")
              (if reference.citedNow "--cited-now")
            }}
          >
            <a class="ai-search-references__link" href={{reference.url}}>
              {{dReplaceEmoji reference.title}}
            </a>
            <div class="ai-search-references__meta">
              {{#if reference.category}}
                {{dCategoryLink reference.category link=false}}
              {{/if}}
              {{#each reference.kindLabels as |kind|}}
                <span class="ai-search-references__kind --{{kind.kind}}">
                  {{kind.label}}
                </span>
              {{/each}}
              {{#if reference.isNew}}
                <span class="ai-search-references__movement">
                  {{i18n "discourse_ai.ai_search.reference_new"}}
                </span>
              {{else if (gt reference.movement 0)}}
                <span
                  class="ai-search-references__movement"
                  title={{i18n
                    "discourse_ai.ai_search.moved_up"
                    count=reference.movedBy
                  }}
                >
                  {{dIcon "arrow-up"}}{{reference.movedBy}}
                </span>
              {{else if (lt reference.movement 0)}}
                <span
                  class="ai-search-references__movement"
                  title={{i18n
                    "discourse_ai.ai_search.moved_down"
                    count=reference.movedBy
                  }}
                >
                  {{dIcon "arrow-down"}}{{reference.movedBy}}
                </span>
              {{/if}}
            </div>
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
