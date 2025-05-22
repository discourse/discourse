import { fn } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import CategorySelector from "select-kit/components/category-selector";

const Categories = <template>
  <div class="control-group category-notifications">
    <label class="control-label">{{i18n "user.categories_settings"}}</label>

    <div
      class="controls tracking-controls tracking-controls__watched-categories"
    >
      <label>{{icon "d-watching"}} {{i18n "user.watched_categories"}}</label>
      {{#if @canSee}}
        <a class="show-tracking" href={{@model.watchingTopicsPath}}>{{i18n
            "user.tracked_topics_link"
          }}</a>
      {{/if}}
      <CategorySelector
        @categories={{@model.watchedCategories}}
        @blockedCategories={{@selectedCategories}}
        @onChange={{fn (mut @model.watchedCategories)}}
      />
    </div>
    <div class="instructions">{{i18n
        "user.watched_categories_instructions"
      }}</div>

    <div
      class="controls tracking-controls tracking-controls__tracked-categories"
    >
      <label>{{icon "d-tracking"}} {{i18n "user.tracked_categories"}}</label>
      {{#if @canSee}}
        <a class="show-tracking" href={{@model.trackingTopicsPath}}>{{i18n
            "user.tracked_topics_link"
          }}</a>
      {{/if}}
      <CategorySelector
        @categories={{@model.trackedCategories}}
        @blockedCategories={{@selectedCategories}}
        @onChange={{fn (mut @model.trackedCategories)}}
      />
    </div>
    <div class="instructions">{{i18n
        "user.tracked_categories_instructions"
      }}</div>

    <div
      class="controls tracking-controls tracking-controls__watched-first-categories"
    >
      <label>{{icon "d-watching-first"}}
        {{i18n "user.watched_first_post_categories"}}</label>
      <CategorySelector
        @categories={{@model.watchedFirstPostCategories}}
        @blockedCategories={{@selectedCategories}}
        @onChange={{fn (mut @model.watchedFirstPostCategories)}}
      />
    </div>
    <div class="instructions">{{i18n
        "user.watched_first_post_categories_instructions"
      }}</div>

    {{#if @siteSettings.mute_all_categories_by_default}}
      <div
        class="controls tracking-controls tracking-controls__regular-categories"
      >
        <label>{{icon "d-regular"}} {{i18n "user.regular_categories"}}</label>
        <CategorySelector
          @categories={{@model.regularCategories}}
          @blockedCategories={{@selectedCategories}}
          @onChange={{fn (mut @model.regularCategories)}}
        />
      </div>
      <div class="instructions">{{i18n
          "user.regular_categories_instructions"
        }}</div>
    {{else}}
      <div
        class="controls tracking-controls tracking-controls__muted-categories"
      >
        <label>{{icon "d-muted"}} {{i18n "user.muted_categories"}}</label>

        {{#if @canSee}}
          <a class="show-tracking" href={{@model.mutedTopicsPath}}>{{i18n
              "user.tracked_topics_link"
            }}</a>
        {{/if}}

        <CategorySelector
          @categories={{@model.mutedCategories}}
          @blockedCategories={{@selectedCategories}}
          @onChange={{fn (mut @model.mutedCategories)}}
        />
      </div>

      <div class="instructions">{{i18n
          (if
            @hideMutedTags
            "user.muted_categories_instructions"
            "user.muted_categories_instructions_dont_hide"
          )
        }}</div>
    {{/if}}
  </div>

  <span>
    <PluginOutlet
      @name="user-preferences-categories"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@model save=@save}}
    />
  </span>

  <br />

  <span>
    <PluginOutlet
      @name="user-custom-controls"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@model}}
    />
  </span>
</template>;

export default Categories;
