import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { i18n } from "discourse-i18n";

const Categories = <template>
  <@form.Field
    @name="watched_category_ids"
    @title={{i18n "user.watched_categories"}}
    @format="large"
    @description={{i18n "user.watched_categories_instructions"}}
    as |field|
  >
    <field.Custom>

      <CategorySelector
        @categories={{field.value}}
        @blockedCategories={{@selectedCategories}}
        @onChange={{field.set}}
      />
      {{#if @canSee}}
        <a class="show-tracking" href={{@model.watchingTopicsPath}}>{{i18n
            "user.tracked_topics_link"
          }}</a>
      {{/if}}
    </field.Custom>

  </@form.Field>

  <@form.Field
    @name="tracked_category_ids"
    @title={{i18n "user.tracked_categories"}}
    @format="large"
    @description={{i18n "user.tracked_categories_instructions"}}
    as |field|
  >
    <field.Custom>

      <CategorySelector
        @categories={{field.value}}
        @blockedCategories={{@selectedCategories}}
        @onChange={{field.set}}
      />
      {{#if @canSee}}
        <a class="show-tracking" href={{@model.trackingTopicsPath}}>{{i18n
            "user.tracked_topics_link"
          }}</a>
      {{/if}}
    </field.Custom>

  </@form.Field>

  <@form.Field
    @name="watched_first_post_category_ids"
    @title={{i18n "user.watched_first_post_categories"}}
    @format="large"
    @description={{i18n "user.watched_first_post_categories_instructions"}}
    as |field|
  >
    <field.Custom>

      <CategorySelector
        @categories={{field.value}}
        @blockedCategories={{@selectedCategories}}
        @onChange={{field.set}}
      />

    </field.Custom>
  </@form.Field>

  {{#if @siteSettings.mute_all_categories_by_default}}
    <@form.Field
      @name="regular_category_ids"
      @title={{i18n "user.regular_categories"}}
      @format="large"
      @description={{i18n "user.regular_categories_instructions"}}
      as |field|
    >
      <field.Custom>
        <CategorySelector
          @categories={{field.value}}
          @blockedCategories={{@selectedCategories}}
          @onChange={{field.set}}
        />
      </field.Custom>
    </@form.Field>
  {{else}}
    <@form.Field
      @name="muted_category_ids"
      @title={{i18n "user.muted_categories"}}
      @format="large"
      @description={{i18n
        (if
          @hideMutedTags
          "user.muted_categories_instructions"
          "user.muted_categories_instructions_dont_hide"
        )
      }}
      as |field|
    >
      <field.Custom>
        <CategorySelector
          @categories={{field.value}}
          @blockedCategories={{@selectedCategories}}
          @onChange={{field.set}}
          @formItem={{true}}
        />
        {{#if @canSee}}
          <a class="show-tracking" href={{@model.mutedTopicsPath}}>{{i18n
              "user.tracked_topics_link"
            }}</a>
        {{/if}}
      </field.Custom>

    </@form.Field>
  {{/if}}

  <PluginOutlet
    @name="user-preferences-categories"
    @connectorTagName="div"
    @outletArgs={{lazyHash model=@model form=@form}}
  />

  <PluginOutlet
    @name="user-custom-controls"
    @connectorTagName="div"
    @outletArgs={{lazyHash model=@model form=@form}}
  />
</template>;

export default Categories;
