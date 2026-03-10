import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class EditCategoryAdditionalSiteSettings extends Component {
  @tracked expanded = false;

  get label() {
    return i18n("category.type_settings_schema.more_settings", {
      count: this.args.settings.length,
    });
  }

  @bind
  toggle() {
    this.expanded = !this.expanded;
  }

  <template>
    {{#if @settings.length}}
      <button
        type="button"
        class="btn-transparent additional-site-settings-toggle"
        {{on "click" this.toggle}}
      >
        {{this.label}}
        {{#if this.expanded}}
          {{icon "angle-up"}}
        {{else}}
          {{icon "angle-down"}}
        {{/if}}
      </button>

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
