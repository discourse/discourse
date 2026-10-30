import { fn } from "@ember/helper";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import CategorySelector from "discourse/select-kit/components/category-selector";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

/** Ids of the categories held by the other lists, which a list must not offer. */
function otherCategoryIds(selected, own) {
  const held = new Set((own ?? []).map((category) => category.id));
  return (selected ?? [])
    .map((category) => category.id)
    .filter((id) => !held.has(id));
}

export default <template>
  <form class="groups-form form-vertical groups-notifications-form">
    <div class="control-group">
      <label class="control-label">{{i18n
          "groups.manage.categories.long_title"
        }}</label>
      <div>{{i18n "groups.manage.categories.description"}}</div>
    </div>

    <div class="control-group">
      <label id="group-watching-categories-label">
        {{~dIcon "d-watching"}}
        {{i18n "groups.notifications.watching.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-selector"
          @ariaLabelledBy="group-watching-categories-label"
          @exclude={{otherCategoryIds
            @controller.selectedCategories
            @controller.model.watchingCategories
          }}
          @multiple={{true}}
          @onChange={{fn (mut @controller.model.watchingCategories)}}
          @value={{@controller.model.watchingCategories}}
        />
      {{else}}
        <CategorySelector
          @blockedCategories={{@controller.selectedCategories}}
          @categories={{@controller.model.watchingCategories}}
          @onChange={{fn (mut @controller.model.watchingCategories)}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.categories.watched_categories_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-tracking-categories-label">
        {{~dIcon "d-tracking"}}
        {{i18n "groups.notifications.tracking.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-selector"
          @ariaLabelledBy="group-tracking-categories-label"
          @exclude={{otherCategoryIds
            @controller.selectedCategories
            @controller.model.trackingCategories
          }}
          @multiple={{true}}
          @onChange={{fn (mut @controller.model.trackingCategories)}}
          @value={{@controller.model.trackingCategories}}
        />
      {{else}}
        <CategorySelector
          @blockedCategories={{@controller.selectedCategories}}
          @categories={{@controller.model.trackingCategories}}
          @onChange={{fn (mut @controller.model.trackingCategories)}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.categories.tracked_categories_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-watching-first-post-categories-label">
        {{~dIcon "d-watching-first"}}
        {{i18n "groups.notifications.watching_first_post.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-selector"
          @ariaLabelledBy="group-watching-first-post-categories-label"
          @exclude={{otherCategoryIds
            @controller.selectedCategories
            @controller.model.watchingFirstPostCategories
          }}
          @multiple={{true}}
          @onChange={{fn (mut @controller.model.watchingFirstPostCategories)}}
          @value={{@controller.model.watchingFirstPostCategories}}
        />
      {{else}}
        <CategorySelector
          @blockedCategories={{@controller.selectedCategories}}
          @categories={{@controller.model.watchingFirstPostCategories}}
          @onChange={{fn (mut @controller.model.watchingFirstPostCategories)}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n
          "groups.manage.categories.watching_first_post_categories_instructions"
        }}
      </div>
    </div>

    <div class="control-group">
      <label id="group-regular-categories-label">
        {{~dIcon "d-regular"}}
        {{i18n "groups.notifications.regular.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-selector"
          @ariaLabelledBy="group-regular-categories-label"
          @exclude={{otherCategoryIds
            @controller.selectedCategories
            @controller.model.regularCategories
          }}
          @multiple={{true}}
          @onChange={{fn (mut @controller.model.regularCategories)}}
          @value={{@controller.model.regularCategories}}
        />
      {{else}}
        <CategorySelector
          @blockedCategories={{@controller.selectedCategories}}
          @categories={{@controller.model.regularCategories}}
          @onChange={{fn (mut @controller.model.regularCategories)}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.categories.regular_categories_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-muted-categories-label">
        {{~dIcon "d-muted"}}
        {{i18n "groups.notifications.muted.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-selector"
          @ariaLabelledBy="group-muted-categories-label"
          @exclude={{otherCategoryIds
            @controller.selectedCategories
            @controller.model.mutedCategories
          }}
          @multiple={{true}}
          @onChange={{fn (mut @controller.model.mutedCategories)}}
          @value={{@controller.model.mutedCategories}}
        />
      {{else}}
        <CategorySelector
          @blockedCategories={{@controller.selectedCategories}}
          @categories={{@controller.model.mutedCategories}}
          @onChange={{fn (mut @controller.model.mutedCategories)}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.categories.muted_categories_instructions"}}
      </div>
    </div>

    <GroupManageSaveButton @model={{@controller.model}} />
  </form>
</template>
