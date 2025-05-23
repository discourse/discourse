import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class Types extends Component {
  @service search;

  get filteredResultTypes() {
    // return only topic result types
    if (this.args.topicResultsOnly) {
      return this.args.resultTypes.filter(
        (resultType) => resultType.type === "topic"
      );
    }

    // return all result types minus topics
    return this.args.resultTypes.filter(
      (resultType) => resultType.type !== "topic"
    );
  }

  @action
  onClick({ resultType, result }, event) {
    logSearchLinkClick({
      searchLogId: this.args.searchLogId,
      searchResultId: result.id,
      searchResultType: resultType.type,
    });

    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    this.routeToSearchResult(event.currentTarget.href);
  }

  @action
  onKeydown({ resultType, result }, event) {
    if (event.key === "Escape") {
      this.args.closeSearchMenu();
      event.preventDefault();
      return false;
    } else if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      logSearchLinkClick({
        searchLogId: this.args.searchLogId,
        searchResultId: result.id,
        searchResultType: resultType.type,
      });
      this.routeToSearchResult(event.target.href);
      return false;
    }

    this.search.handleResultInsertion(event);
    this.search.handleArrowUpOrDown(event);
  }

  @action
  routeToSearchResult(href) {
    DiscourseURL.routeTo(href);
    this.args.closeSearchMenu();
  }

  <template>
    {{#each this.filteredResultTypes as |resultType|}}
      <div class={{resultType.componentName}}>
        <PluginOutlet
          @name="search-menu-results-type-top"
          @outletArgs={{lazyHash resultType=resultType}}
        />
        <ul
          class="list"
          aria-label={{concat (i18n "search.results") " " resultType.type}}
        >
          {{#each resultType.results as |result|}}
            {{! template-lint-disable no-pointer-down-event-binding }}
            {{! template-lint-disable no-invalid-interactive }}
            <li
              class="item"
              {{on
                "keydown"
                (fn this.onKeydown (hash resultType=resultType result=result))
              }}
            >
              <a
                href={{or result.url result.path}}
                {{on
                  "click"
                  (fn this.onClick (hash resultType=resultType result=result))
                }}
                class="search-link"
              >
                <resultType.component
                  @result={{result}}
                  @displayNameWithUser={{@displayNameWithUser}}
                />
              </a>
            </li>
          {{/each}}
        </ul>
      </div>
    {{/each}}
  </template>
}
