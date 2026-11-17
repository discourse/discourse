import { fn } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CategorySelector from "discourse/select-kit/components/category-selector";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const Categories = <template>
  <div class="control-group category-notifications">
    <label class="control-label">{{i18n "user.categories_settings"}}</label>

    <div
      class="controls tracking-controls tracking-controls__watched-categories"
    >
      <label>{{dIcon "d-watching"}} {{i18n "user.watched_categories"}}</label>
      {{#if @canSee}}
        <a class="show-tracking" href={{@model.watchingTopicsPath}}>{{i18n
            "user.tracked_topics_link"
          }}</a>
      {{/if}}
      <CategorySelector
        @blockedCategories={{@selectedCategories}}
        @categories={{@model.watchedCategories}}
        @onChange={{fn (mut @model.watchedCategories)}}
      />
    </div>
    <div class="instructions">{{i18n
        "user.watched_categories_instructions"
      }}</div>

    <div
      class="controls tracking-controls tracking-controls__tracked-categories"
    >
      <label>{{dIcon "d-tracking"}} {{i18n "user.tracked_categories"}}</label>
      {{#if @canSee}}
        <a class="show-tracking" href={{@model.trackingTopicsPath}}>{{i18n
            "user.tracked_topics_link"
          }}</a>
      {{/if}}
      <CategorySelector
        @blockedCategories={{@selectedCategories}}
        @categories={{@model.trackedCategories}}
        @onChange={{fn (mut @model.trackedCategories)}}
      />
    </div>
    <div class="instructions">{{i18n
        "user.tracked_categories_instructions"
      }}</div>

    <div
      class="controls tracking-controls tracking-controls__watched-first-categories"
    >
      <label>{{dIcon "d-watching-first"}}
        {{i18n "user.watched_first_post_categories"}}</label>
      <CategorySelector
        @blockedCategories={{@selectedCategories}}
        @categories={{@model.watchedFirstPostCategories}}
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
        <label>{{dIcon "d-regular"}} {{i18n "user.regular_categories"}}</label>
        <CategorySelector
          @blockedCategories={{@selectedCategories}}
          @categories={{@model.regularCategories}}
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
        <label>{{dIcon "d-muted"}} {{i18n "user.muted_categories"}}</label>

        {{#if @canSee}}
          <a class="show-tracking" href={{@model.mutedTopicsPath}}>{{i18n
              "user.tracked_topics_link"
            }}</a>
        {{/if}}

        <CategorySelector
          @blockedCategories={{@selectedCategories}}
          @categories={{@model.mutedCategories}}
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
      @connectorTagName="div"
      @name="user-preferences-categories"
      @outletArgs={{lazyHash model=@model save=@save}}
    />
  </span>

  <br />

  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="user-custom-controls"
      @outletArgs={{lazyHash model=@model}}
    />
  </span>
</template>;

export default Categories;
