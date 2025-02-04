import Component from "@ember/component";
import { action } from "@ember/object";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";

@tagName("div")
@classNames("fps-result")
@classNameBindings("bulkSelectEnabled")
@attributeBindings("role")
export default class SearchResultEntry extends Component {
  role = "listitem";

  @action
  logClick(topicId, event) {
    // Avoid click logging when any modifier keys are pressed.
    if (wantsNewWindow(event)) {
      return;
    }

    if (this.searchLogId && topicId) {
      logSearchLinkClick({
        searchLogId: this.searchLogId,
        searchResultId: topicId,
        searchResultType: "topic",
      });
    }
  }
}
