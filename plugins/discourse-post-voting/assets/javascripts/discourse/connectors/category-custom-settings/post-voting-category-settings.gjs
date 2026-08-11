import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

const ALL_CATEGORIES = "all_categories";

const isChecked = (value) => value === true || value === "true";

export default class PostVotingCategorySettings extends Component {
  @service dialog;
  @service siteSettings;

  get savedAllowPostVoting() {
    return isChecked(
      this.args.outletArgs.category?.custom_fields?.allow_post_voting
    );
  }

  @action
  async allowPostVotingChanged(value, { set, name }) {
    await set(name, value);

    if (this.descendantCount === 0) {
      return;
    }

    if (isChecked(value) === this.savedAllowPostVoting) {
      if (this.applyToSubcategoriesPending) {
        await set("custom_fields.apply_post_voting_to_subcategories", false);
      }

      return;
    }

    const applied = await this.dialog.yesNoConfirm({
      message: i18n(
        isChecked(value)
          ? "category.post_voting_subcategories.enable"
          : "category.post_voting_subcategories.disable",
        { count: this.descendantCount }
      ),
    });

    await set("custom_fields.apply_post_voting_to_subcategories", applied);
  }

  // Nothing to opt in or out of when every category is allowed.
  get showAllowPostVoting() {
    return this.siteSettings.post_voting_category_mode !== ALL_CATEGORIES;
  }

  get descendantCount() {
    const count = (category) =>
      (category.subcategories ?? []).reduce(
        (total, subcategory) => total + 1 + count(subcategory),
        0
      );

    const category = this.args.outletArgs.category;
    return category?.id ? count(category) : 0;
  }

  get applyToSubcategoriesPending() {
    return !!this.args.outletArgs.transientData?.custom_fields
      ?.apply_post_voting_to_subcategories;
  }

  // Read from the live form data rather than the saved category so the
  // dependent settings appear as soon as the checkbox is ticked.
  get postVotingAllowed() {
    if (this.siteSettings.post_voting_category_mode === ALL_CATEGORIES) {
      return true;
    }

    return !!this.args.outletArgs.transientData?.custom_fields
      ?.allow_post_voting;
  }

  <template>
    <@outletArgs.form.Section
      @title={{i18n "category.post_voting_settings_heading"}}
      class="category-custom-settings-outlet post-voting-category-settings"
    >
      <@outletArgs.form.Object @name="custom_fields" as |object|>
        {{#if this.showAllowPostVoting}}
          <object.Field
            @name="allow_post_voting"
            @title={{i18n "category.allow_post_voting"}}
            @format="max"
            @type="checkbox"
            @onSet={{this.allowPostVotingChanged}}
            as |field|
          >
            <field.Control>
              {{#if this.applyToSubcategoriesPending}}
                {{i18n
                  "category.post_voting_subcategories.pending"
                  count=this.descendantCount
                }}
              {{/if}}
            </field.Control>
          </object.Field>
        {{/if}}

        {{#if this.postVotingAllowed}}
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
        {{/if}}
      </@outletArgs.form.Object>
    </@outletArgs.form.Section>
  </template>
}
