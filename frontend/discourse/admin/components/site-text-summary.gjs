import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import highlightHTML from "discourse/lib/highlight-html";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const SiteTextHeader = <template>
  <div class="site-text__header">
    <div class="site-text__details">
      <code class="site-text-id">{{@siteText.id}}</code>
      {{#if @statusLabel}}
        <span
          class="site-text__status"
          data-status={{@siteText.status}}
        >{{@statusLabel}}</span>
      {{/if}}
    </div>
    {{yield}}
  </div>
</template>;

export default class SiteTextSummary extends Component {
  @tracked activePreview = "customized";

  get showPreviewTabs() {
    return (
      this.args.siteText.override_value != null &&
      this.args.siteText.preview_default != null
    );
  }

  get statusLabel() {
    switch (this.args.siteText.status) {
      case "unknown":
        return i18n("admin.site_text.status.unknown");
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
  selectPreview(key) {
    this.activePreview = key;
  }

  @action
  highlightSearchTerm(element) {
    const term = this.#searchTerm();

    if (term) {
      const targets = element.matches(".site-text-value")
        ? [element]
        : element.querySelectorAll(".site-text-id, .site-text-value");
      for (const target of targets) {
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
      {{#if this.showPreviewTabs}}
        <DTabs
          class="site-text__preview"
          @active={{this.activePreview}}
          @label={{i18n "admin.site_text.preview.label" key=@siteText.id}}
          @onActivate={{this.selectPreview}}
        >
          <:header as |header|>
            <SiteTextHeader
              @siteText={{@siteText}}
              @statusLabel={{this.statusLabel}}
            >
              <header.Tablist />
            </SiteTextHeader>
          </:header>
          <:default as |tabs|>
            <tabs.Tab
              @key="customized"
              @label={{i18n "admin.site_text.preview.customized"}}
            >
              <div
                class="site-text-value"
                {{didInsert this.highlightSearchTerm}}
              >{{@siteText.override_value}}</div>
            </tabs.Tab>
            <tabs.Tab
              @key="default"
              @label={{i18n "admin.site_text.preview.default"}}
            >
              <div
                class="site-text-value"
                {{didInsert this.highlightSearchTerm}}
              >{{@siteText.preview_default}}</div>
            </tabs.Tab>
          </:default>
        </DTabs>
      {{else}}
        <SiteTextHeader
          @siteText={{@siteText}}
          @statusLabel={{this.statusLabel}}
        />
        <div
          class="site-text-value"
          {{didInsert this.highlightSearchTerm}}
        >{{@siteText.value}}</div>
      {{/if}}
      <DButton
        class="btn-default site-text-edit"
        @action={{fn @editAction @siteText}}
        @label="admin.site_text.edit"
      />
    </div>
  </template>
}
