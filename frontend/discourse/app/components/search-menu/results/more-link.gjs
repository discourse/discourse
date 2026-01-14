import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class MoreLink extends Component {
  @service search;

  get topicResults() {
    const topicResults = this.args.resultTypes.filter(
      (resultType) => resultType.type === "topic"
    );
    return topicResults[0];
  }

  get moreUrl() {
    return this.topicResults.moreUrl && this.topicResults.moreUrl();
  }

  @action
  transitionToMoreUrl(event) {
    event.preventDefault();
    this.args.closeSearchMenu();
    DiscourseURL.routeTo(this.moreUrl);
    return false;
  }

  @action
  moreOfType(type) {
    this.args.updateTypeFilter(type);
    this.args.triggerSearch();
    this.args.closeSearchMenu();
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleArrowUpOrDown(e);
  }

  <template>
    {{#if this.topicResults}}
      {{! template-lint-disable no-invalid-interactive }}
      <div class="search-menu__show-more" {{on "keyup" this.onKeyup}}>
        {{#if this.moreUrl}}
          <a
            href={{this.moreUrl}}
            {{on "click" this.transitionToMoreUrl}}
            class="filter search-link"
          >
            {{i18n "more"}}...
          </a>
        {{else if this.topicResults.more}}
          <a
            {{on "click" (fn this.moreOfType this.topicResults.type)}}
            class="filter search-link"
          >
            {{i18n "more"}}...
          </a>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
