import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";
import DiscourseURL from "discourse/lib/url";

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
}
