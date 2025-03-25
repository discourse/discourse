import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CategorySelector from "select-kit/components/category-selector";

export default RouteTemplate(
  <template>
    <form class="groups-form form-vertical groups-notifications-form">
      <div class="control-group">
        <label class="control-label">{{i18n
            "groups.manage.categories.long_title"
          }}</label>
        <div>{{i18n "groups.manage.categories.description"}}</div>
      </div>

      <div class="control-group">
        <label>{{icon "d-watching"}}
          {{i18n "groups.notifications.watching.title"}}</label>

        <CategorySelector
          @categories={{@controller.model.watchingCategories}}
          @blockedCategories={{@controller.selectedCategories}}
          @onChange={{fn (mut @controller.model.watchingCategories)}}
        />

        <div class="control-instructions">
          {{i18n "groups.manage.categories.watched_categories_instructions"}}
        </div>
      </div>

      <div class="control-group">
        <label>{{icon "d-tracking"}}
          {{i18n "groups.notifications.tracking.title"}}</label>

        <CategorySelector
          @categories={{@controller.model.trackingCategories}}
          @blockedCategories={{@controller.selectedCategories}}
          @onChange={{fn (mut @controller.model.trackingCategories)}}
        />

        <div class="control-instructions">
          {{i18n "groups.manage.categories.tracked_categories_instructions"}}
        </div>
      </div>

      <div class="control-group">
        <label>{{icon "d-watching-first"}}
          {{i18n "groups.notifications.watching_first_post.title"}}</label>

        <CategorySelector
          @categories={{@controller.model.watchingFirstPostCategories}}
          @blockedCategories={{@controller.selectedCategories}}
          @onChange={{fn (mut @controller.model.watchingFirstPostCategories)}}
        />

        <div class="control-instructions">
          {{i18n
            "groups.manage.categories.watching_first_post_categories_instructions"
          }}
        </div>
      </div>

      <div class="control-group">
        <label>{{icon "d-regular"}}
          {{i18n "groups.notifications.regular.title"}}</label>

        <CategorySelector
          @categories={{@controller.model.regularCategories}}
          @blockedCategories={{@controller.selectedCategories}}
          @onChange={{fn (mut @controller.model.regularCategories)}}
        />

        <div class="control-instructions">
          {{i18n "groups.manage.categories.regular_categories_instructions"}}
        </div>
      </div>

      <div class="control-group">
        <label>{{icon "d-muted"}}
          {{i18n "groups.notifications.muted.title"}}</label>

        <CategorySelector
          @categories={{@controller.model.mutedCategories}}
          @blockedCategories={{@controller.selectedCategories}}
          @onChange={{fn (mut @controller.model.mutedCategories)}}
        />

        <div class="control-instructions">
          {{i18n "groups.manage.categories.muted_categories_instructions"}}
        </div>
      </div>

      <GroupManageSaveButton @model={{@controller.model}} />
    </form>
  </template>
);
