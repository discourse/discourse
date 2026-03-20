import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class PostVotingCategorySettings extends Component {
  @service siteSettings;

  @action
  onChangeCreateAsPostVotingDefault(event) {
    this.args.outletArgs.category.custom_fields.create_as_post_voting_default =
      event.target.checked;
  }

  @action
  onChangeOnlyPostVotingInThisCategory(event) {
    this.args.outletArgs.category.custom_fields.only_post_voting_in_this_category =
      event.target.checked;
  }

  <template>
    {{#if this.siteSettings.enable_simplified_category_creation}}
      <@outletArgs.form.Section
        @title={{i18n "category.post_voting_settings_heading"}}
        class="category-custom-settings-outlet post-voting-category-settings"
      >
        <@outletArgs.form.Object @name="custom_fields" as |object|>
          <object.Field
            @name="create_as_post_voting_default"
            @title={{i18n "category.create_as_post_voting_default"}}
            @format="max"
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </object.Field>

          <object.Field
            @name="only_post_voting_in_this_category"
            @title={{i18n "category.only_post_voting_in_this_category"}}
            @format="max"
            @type="checkbox"
            as |field|
          >
            <field.Control />
          </object.Field>
        </@outletArgs.form.Object>
      </@outletArgs.form.Section>
    {{else}}
      <div
        class="category-custom-settings-outlet post-voting-category-settings"
      >
        <h3>{{i18n "category.post_voting_settings_heading"}}</h3>
        <section class="field">
          <label class="checkbox-label">
            <input
              id="create-as-post-voting-default"
              type="checkbox"
              checked={{@outletArgs.category.custom_fields.create_as_post_voting_default}}
              {{on "change" this.onChangeCreateAsPostVotingDefault}}
            />
            {{i18n "category.create_as_post_voting_default"}}
          </label>
          <label class="checkbox-label">
            <input
              id="only-post-voting-in-this-category"
              type="checkbox"
              checked={{@outletArgs.category.custom_fields.only_post_voting_in_this_category}}
              {{on "change" this.onChangeOnlyPostVotingInThisCategory}}
            />
            {{i18n "category.only_post_voting_in_this_category"}}
          </label>
        </section>
      </div>
    {{/if}}
  </template>
}
