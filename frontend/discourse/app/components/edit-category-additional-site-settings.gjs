import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DButton from "discourse/components/d-button";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class EditCategoryAdditionalSiteSettings extends Component {
  @tracked expanded = false;

  get label() {
    return i18n("category.type_settings_schema.more_settings", {
      count: this.args.settings.length,
    });
  }

  get icon() {
    return this.expanded ? "angle-up" : "angle-down";
  }

  @bind
  toggle() {
    this.expanded = !this.expanded;
  }

  <template>
    {{#if @settings.length}}
      <DButton
        @action={{this.toggle}}
        @translatedLabel={{this.label}}
        @icon={{this.icon}}
        class="btn-default additional-site-settings-toggle"
      />

      {{#if this.expanded}}
        <div class="additional-site-settings">
          {{#each @settings as |entry|}}
            <@SchemaFormField
              @category={{@category}}
              @entry={{entry}}
              @formObject={{@formObject}}
            />
          {{/each}}
        </div>
      {{/if}}
    {{/if}}
  </template>
}
