import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import NewListHeaderControls from "discourse/components/topic-list/new-list-header-controls";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import { i18n } from "discourse-i18n";

export default class FilterNewNavigation extends Component {
  @service filterTopicTracking;
  @service router;

  get counts() {
    if (this.args.query === this.filterTopicTracking.query) {
      return this.filterTopicTracking;
    }
  }

  get newLabel() {
    const count = this.counts?.newTopicsCount + this.counts?.newRepliesCount;
    return count > 0
      ? i18n("filters.new.title_with_count", { count })
      : i18n("filters.new.title");
  }

  get selection() {
    return { new: "all", "new-topics": "topics", "new-replies": "replies" }[
      this.args.subset
    ];
  }

  @action
  changeSubset(subset) {
    this.router.transitionTo("discovery.filter", {
      queryParams: { subset: subset ? `new-${subset}` : "new" },
    });
  }

  <template>
    <div class="filter-new-navigation" ...attributes>
      <DHorizontalOverflowNav @className="filter-new-navigation__tabs">
        <li>
          <LinkTo
            data-filter-view="all"
            @current-when={{if this.selection false true}}
            @query={{hash subset=null}}
            @route="discovery.filter"
          >{{i18n "filters.new.all"}}</LinkTo>
        </li>
        <li>
          <LinkTo
            data-filter-view="new"
            @current-when={{if this.selection true false}}
            @query={{hash subset="new"}}
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
