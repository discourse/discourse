import { fn, hash } from "@ember/helper";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import { i18n } from "discourse-i18n";

function updateTags(model, field, tags) {
  model.set(field, tags);
}

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
      <label id="group-watching-tags-label">
        {{~dIcon "d-watching"}}
        {{i18n "groups.notifications.watching.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectTag
          @ariaLabelledBy="group-watching-tags-label"
          @exclude={{@controller.selectedTags}}
          @ignoreRestrictions={{true}}
          @maximum={{false}}
          @multiple={{true}}
          @onChange={{fn updateTags @controller.model "watching_tags"}}
          @value={{@controller.model.watching_tags}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @blockedTags={{@controller.selectedTags}}
          @everyTag={{true}}
          @onChange={{fn updateTags @controller.model "watching_tags"}}
          @options={{hash allowAny=false}}
          @tags={{@controller.model.watching_tags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.tags.watched_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-tracking-tags-label">
        {{~dIcon "d-tracking"}}
        {{i18n "groups.notifications.tracking.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectTag
          @ariaLabelledBy="group-tracking-tags-label"
          @exclude={{@controller.selectedTags}}
          @ignoreRestrictions={{true}}
          @maximum={{false}}
          @multiple={{true}}
          @onChange={{fn updateTags @controller.model "tracking_tags"}}
          @value={{@controller.model.tracking_tags}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @blockedTags={{@controller.selectedTags}}
          @everyTag={{true}}
          @onChange={{fn updateTags @controller.model "tracking_tags"}}
          @options={{hash allowAny=false}}
          @tags={{@controller.model.tracking_tags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.tags.tracked_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-watching-first-post-tags-label">
        {{~dIcon "d-watching-first"}}
        {{i18n "groups.notifications.watching_first_post.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectTag
          @ariaLabelledBy="group-watching-first-post-tags-label"
          @exclude={{@controller.selectedTags}}
          @ignoreRestrictions={{true}}
          @maximum={{false}}
          @multiple={{true}}
          @onChange={{fn
            updateTags
            @controller.model
            "watching_first_post_tags"
          }}
          @value={{@controller.model.watching_first_post_tags}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @blockedTags={{@controller.selectedTags}}
          @everyTag={{true}}
          @onChange={{fn
            updateTags
            @controller.model
            "watching_first_post_tags"
          }}
          @options={{hash allowAny=false}}
          @tags={{@controller.model.watching_first_post_tags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.tags.watching_first_post_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-regular-tags-label">
        {{~dIcon "d-regular"}}
        {{i18n "groups.notifications.regular.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectTag
          @ariaLabelledBy="group-regular-tags-label"
          @exclude={{@controller.selectedTags}}
          @ignoreRestrictions={{true}}
          @maximum={{false}}
          @multiple={{true}}
          @onChange={{fn updateTags @controller.model "regular_tags"}}
          @value={{@controller.model.regular_tags}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @blockedTags={{@controller.selectedTags}}
          @everyTag={{true}}
          @onChange={{fn updateTags @controller.model "regular_tags"}}
          @options={{hash allowAny=false}}
          @tags={{@controller.model.regular_tags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.tags.regular_tags_instructions"}}
      </div>
    </div>

    <div class="control-group">
      <label id="group-muted-tags-label">
        {{~dIcon "d-muted"}}
        {{i18n "groups.notifications.muted.title"~}}
      </label>

      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if @controller.siteSettings.enable_new_select_controls}}
        <DSelectTag
          @ariaLabelledBy="group-muted-tags-label"
          @exclude={{@controller.selectedTags}}
          @ignoreRestrictions={{true}}
          @maximum={{false}}
          @multiple={{true}}
          @onChange={{fn updateTags @controller.model "muted_tags"}}
          @value={{@controller.model.muted_tags}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @blockedTags={{@controller.selectedTags}}
          @everyTag={{true}}
          @onChange={{fn updateTags @controller.model "muted_tags"}}
          @options={{hash allowAny=false}}
          @tags={{@controller.model.muted_tags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}

      <div class="control-instructions">
        {{i18n "groups.manage.tags.muted_tags_instructions"}}
      </div>
    </div>

    <GroupManageSaveButton @model={{@controller.model}} />
  </form>
</template>
