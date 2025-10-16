import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse/lib/decorators";
import highlightHTML from "discourse/lib/highlight-html";

export default class SiteTextSummary extends Component {
  @action
  highlightSearchTerm(element) {
    const term = this.#searchTerm();

    if (term) {
      highlightHTML(
        element.querySelector(".site-text-id, .site-text-value"),
        term,
        {
          className: "text-highlight",
        }
      );
    }
  }

  @action
  onClick() {
    this.args.editAction(this.siteText);
  }

  @bind
  #searchTerm() {
    const regex = this.args.searchRegex;
    const siteText = this.args.siteText;

    if (regex && siteText) {
      const matches = siteText.value.match(new RegExp(regex, "i"));
      if (matches) {
        return matches[0];
      }
    }

    return this.args.term;
  }

  <template>
    <div
      class={{concatClass "site-text" (if @siteText.overridden "overridden")}}
      {{didInsert this.highlightSearchTerm}}
      data-site-text-id={{@siteText.id}}
    >
      <DButton
        @label="admin.site_text.edit"
        @action={{fn @editAction @siteText}}
        class="btn-default site-text-edit"
      />
      <h3 class="site-text-id">{{@siteText.id}}</h3>
      <div class="site-text-value">{{@siteText.value}}</div>

      <div class="clearfix"></div>
    </div>
  </template>
}
