import { hash } from "@ember/helper";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <form class="groups-form form-vertical groups-notifications-form">

    <PluginOutlet
      @connectorTagName="div"
      @name="before-manage-group-tags"
      @outletArgs={{lazyHash model=@controller.model}}
    />

    <div class="control-group">
      <label class="control-label">{{i18n
          "groups.manage.tags.long_title"
        }}</label>
      <div>{{i18n "groups.manage.tags.description"}}</div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-watching"}}
        {{i18n "groups.notifications.watching.title"}}</label>

      <TagChooser
        @blockedTags={{@controller.selectedTags}}
        @everyTag={{true}}
        @options={{hash allowAny=false}}
        @tags={{@controller.model.watching_tags}}
        @unlimitedTagCount={{true}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.tags.watched_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-tracking"}}
        {{i18n "groups.notifications.tracking.title"}}</label>

      <TagChooser
        @blockedTags={{@controller.selectedTags}}
        @everyTag={{true}}
        @options={{hash allowAny=false}}
        @tags={{@controller.model.tracking_tags}}
        @unlimitedTagCount={{true}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.tags.tracked_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-watching-first"}}
        {{i18n "groups.notifications.watching_first_post.title"}}</label>

      <TagChooser
        @blockedTags={{@controller.selectedTags}}
        @everyTag={{true}}
        @options={{hash allowAny=false}}
        @tags={{@controller.model.watching_first_post_tags}}
        @unlimitedTagCount={{true}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.tags.watching_first_post_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-regular"}}
        {{i18n "groups.notifications.regular.title"}}</label>

      <TagChooser
        @blockedTags={{@controller.selectedTags}}
        @everyTag={{true}}
        @options={{hash allowAny=false}}
        @tags={{@controller.model.regular_tags}}
        @unlimitedTagCount={{true}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.tags.regular_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label>{{dIcon "d-muted"}}
        {{i18n "groups.notifications.muted.title"}}</label>

      <TagChooser
        @blockedTags={{@controller.selectedTags}}
        @everyTag={{true}}
        @options={{hash allowAny=false}}
        @tags={{@controller.model.muted_tags}}
        @unlimitedTagCount={{true}}
      />

      <div class="control-instructions">
        {{i18n "groups.manage.tags.muted_tags_instructions"}}
      </div>
    </div>

    <GroupManageSaveButton @model={{@controller.model}} />
  </form>
</template>
