import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const Tags = <template>
  {{#if @siteSettings.tagging_enabled}}
    <div class="control-group tag-notifications">
      <label class="control-label">{{i18n "user.tag_settings"}}</label>

      <div class="controls tracking-controls tracking-controls__watched-tags">
        <label>{{dIcon "d-watching" class="icon watching"}}
          {{i18n "user.watched_tags"}}</label>
        <TagChooser
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @options={{hash allowAny=false}}
          @tags={{@model.watched_tags}}
          @unlimitedTagCount={{true}}
        />
      </div>

      <div class="instructions">{{i18n "user.watched_tags_instructions"}}</div>

      <div class="controls tracking-controls tracking-controls__tracked-tags">
        <label>{{dIcon "d-tracking" class="icon tracking"}}
          {{i18n "user.tracked_tags"}}</label>
        <TagChooser
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @options={{hash allowAny=false}}
          @tags={{@model.tracked_tags}}
          @unlimitedTagCount={{true}}
        />
      </div>

      <div class="instructions">{{i18n "user.tracked_tags_instructions"}}</div>

      <div
        class="controls tracking-controls tracking-controls__watched-first-post-tags"
      >
        <label>{{dIcon "d-watching-first" class="icon watching-first-post"}}
          {{i18n "user.watched_first_post_tags"}}</label>
        <TagChooser
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @options={{hash allowAny=false}}
          @tags={{@model.watching_first_post_tags}}
          @unlimitedTagCount={{true}}
        />
      </div>

      <div class="instructions">
        {{i18n "user.watched_first_post_tags_instructions"}}
      </div>

      <div class="controls tracking-controls tracking-controls__muted-tags">
        <label>{{dIcon "d-muted" class="icon muted"}}
          {{i18n "user.muted_tags"}}</label>
        <TagChooser
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @options={{hash allowAny=false}}
          @tags={{@model.muted_tags}}
          @unlimitedTagCount={{true}}
        />
      </div>
      <div class="instructions">{{i18n "user.muted_tags_instructions"}}</div>
    </div>

    <PluginOutlet
      @connectorTagName="div"
      @name="user-preferences-tags"
      @outletArgs={{lazyHash model=@model save=@save}}
    />
    <PluginOutlet
      @connectorTagName="div"
      @name="user-custom-controls"
      @outletArgs={{lazyHash model=@model}}
    />
  {{/if}}
</template>;

export default Tags;
