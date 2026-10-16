import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import highlightHTML from "discourse/lib/highlight-html";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class SiteTextSummary extends Component {
  get statusLabel() {
    switch (this.args.siteText.status) {
      case "outdated":
        return i18n("admin.site_text.status.outdated");
      case "invalid_interpolation_keys":
        return i18n("admin.site_text.status.invalid");
      default:
        return this.args.siteText.overridden
          ? i18n("admin.site_text.status.customized")
          : null;
    }
  }

  @action
  highlightSearchTerm(element) {
    const term = this.#searchTerm();

    if (term) {
      for (const target of element.querySelectorAll(
        ".site-text-id, .site-text-value"
      )) {
        highlightHTML(target, term, { className: "text-highlight" });
      }
    }
  }

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
      class={{dConcatClass "site-text" (if @siteText.overridden "overridden")}}
      data-site-text-id={{@siteText.id}}
      {{didInsert this.highlightSearchTerm}}
    >
      <div class="site-text__details">
        <code class="site-text-id">{{@siteText.id}}</code>
        {{#if this.statusLabel}}
          <span
            class="site-text__status"
            data-status={{@siteText.status}}
          >{{this.statusLabel}}</span>
        {{/if}}
      </div>
      <div class="site-text-value">{{@siteText.value}}</div>
      <DButton
        class="btn-default site-text-edit"
        @action={{fn @editAction @siteText}}
        @label="admin.site_text.edit"
      />
    </div>
  </template>
}
