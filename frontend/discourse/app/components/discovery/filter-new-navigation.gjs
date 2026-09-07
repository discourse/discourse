import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import NewListHeaderControls from "discourse/components/topic-list/new-list-header-controls";
import {
  filterNewQuery,
  parseFilterNewQuery,
} from "discourse/lib/filter-new-query";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import { i18n } from "discourse-i18n";

export default class FilterNewNavigation extends Component {
  @service filterTopicTracking;

  get allQuery() {
    return filterNewQuery(this.args.query);
  }

  get counts() {
    if (
      parseFilterNewQuery(this.args.query).baseQuery ===
      this.filterTopicTracking.query
    ) {
      return this.filterTopicTracking;
    }
  }

  get newLabel() {
    const count = this.counts?.newTopicsCount + this.counts?.newRepliesCount;
    return count > 0
      ? i18n("filters.new.title_with_count", { count })
      : i18n("filters.new.title");
  }

  get newQuery() {
    return filterNewQuery(this.args.query, "all");
  }

  get selection() {
    return parseFilterNewQuery(this.args.query).selection;
  }

  @action
  changeSubset(subset) {
    this.args.updateQuery(filterNewQuery(this.args.query, subset || "all"));
  }

  <template>
    <div class="filter-new-navigation" ...attributes>
      <DHorizontalOverflowNav @className="filter-new-navigation__tabs">
        <li>
          <LinkTo
            data-filter-view="all"
            @current-when={{if this.selection false true}}
            @query={{hash q=this.allQuery}}
            @route="discovery.filter"
          >{{i18n "filters.new.all"}}</LinkTo>
        </li>
        <li>
          <LinkTo
            data-filter-view="new"
            @current-when={{if this.selection true false}}
            @query={{hash q=this.newQuery}}
            @route="discovery.filter"
          >{{this.newLabel}}</LinkTo>
        </li>
      </DHorizontalOverflowNav>
      {{#if this.selection}}
        <div class="topic-replies-toggle-wrapper">
          <NewListHeaderControls
            @changeNewListSubset={{this.changeSubset}}
            @current={{this.selection}}
            @newRepliesCount={{this.counts.newRepliesCount}}
            @newTopicsCount={{this.counts.newTopicsCount}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
