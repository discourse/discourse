import { fn } from "@ember/helper";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import CategorySelector from "discourse/select-kit/components/category-selector";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <form class="groups-form form-vertical groups-notifications-form">
    <div class="control-group">
      <label class="control-label">{{i18n
          "groups.manage.categories.long_title"
        }}</label>
      <div>{{i18n "groups.manage.categories.description"}}</div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-watching"}}
        {{i18n "groups.notifications.watching.title"}}</label>

      <CategorySelector
        @blockedCategories={{@controller.selectedCategories}}
        @categories={{@controller.model.watchingCategories}}
        @onChange={{fn (mut @controller.model.watchingCategories)}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.categories.watched_categories_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-tracking"}}
        {{i18n "groups.notifications.tracking.title"}}</label>

      <CategorySelector
        @blockedCategories={{@controller.selectedCategories}}
        @categories={{@controller.model.trackingCategories}}
        @onChange={{fn (mut @controller.model.trackingCategories)}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.categories.tracked_categories_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-watching-first"}}
        {{i18n "groups.notifications.watching_first_post.title"}}</label>

      <CategorySelector
        @blockedCategories={{@controller.selectedCategories}}
        @categories={{@controller.model.watchingFirstPostCategories}}
        @onChange={{fn (mut @controller.model.watchingFirstPostCategories)}}
      />

      <div class="control-instructions">
        {{i18n
          "groups.manage.categories.watching_first_post_categories_instructions"
        }}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-regular"}}
        {{i18n "groups.notifications.regular.title"}}</label>

      <CategorySelector
        @blockedCategories={{@controller.selectedCategories}}
        @categories={{@controller.model.regularCategories}}
        @onChange={{fn (mut @controller.model.regularCategories)}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.categories.regular_categories_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-muted"}}
        {{i18n "groups.notifications.muted.title"}}</label>

      <CategorySelector
        @blockedCategories={{@controller.selectedCategories}}
        @categories={{@controller.model.mutedCategories}}
        @onChange={{fn (mut @controller.model.mutedCategories)}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.categories.muted_categories_instructions"}}
      </div>
    </div>

    <GroupManageSaveButton @model={{@controller.model}} />
  </form>
</template>
