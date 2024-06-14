import Component from "@ember/component";
import { classNameBindings, classNames } from "@ember-decorators/component";
import highlightHTML from "discourse/lib/highlight-html";

@classNames("site-text")
@classNameBindings("siteText.overridden")
export default class SiteTextSummary extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    const term = this._searchTerm();

    if (term) {
      highlightHTML(
        this.element.querySelector(".site-text-id, .site-text-value"),
        term,
        {
          className: "text-highlight",
        }
      );
    }
  }

  click() {
    this.editAction(this.siteText);
  }

  _searchTerm() {
    const regex = this.searchRegex;
    const siteText = this.siteText;

    if (regex && siteText) {
      const matches = siteText.value.match(new RegExp(regex, "i"));
      if (matches) {
        return matches[0];
      }
    }

    return this.term;
  }
}
