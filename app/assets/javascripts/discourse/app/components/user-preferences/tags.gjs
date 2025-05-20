import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import TagChooser from "select-kit/components/tag-chooser";

const Tags = <template>
  {{#if @siteSettings.tagging_enabled}}
    <div class="control-group tag-notifications">
      <label class="control-label">{{i18n "user.tag_settings"}}</label>

      <div class="controls tracking-controls tracking-controls__watched-tags">
        <label>{{icon "d-watching" class="icon watching"}}
          {{i18n "user.watched_tags"}}</label>
        <TagChooser
          @tags={{@model.watched_tags}}
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @unlimitedTagCount={{true}}
          @options={{hash allowAny=false}}
        />
      </div>

      <div class="instructions">{{i18n "user.watched_tags_instructions"}}</div>

      <div class="controls tracking-controls tracking-controls__tracked-tags">
        <label>{{icon "d-tracking" class="icon tracking"}}
          {{i18n "user.tracked_tags"}}</label>
        <TagChooser
          @tags={{@model.tracked_tags}}
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @unlimitedTagCount={{true}}
          @options={{hash allowAny=false}}
        />
      </div>

      <div class="instructions">{{i18n "user.tracked_tags_instructions"}}</div>

      <div
        class="controls tracking-controls tracking-controls__watched-first-post-tags"
      >
        <label>{{icon "d-watching-first" class="icon watching-first-post"}}
          {{i18n "user.watched_first_post_tags"}}</label>
        <TagChooser
          @tags={{@model.watching_first_post_tags}}
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @unlimitedTagCount={{true}}
          @options={{hash allowAny=false}}
        />
      </div>

      <div class="instructions">
        {{i18n "user.watched_first_post_tags_instructions"}}
      </div>

      <div class="controls tracking-controls tracking-controls__muted-tags">
        <label>{{icon "d-muted" class="icon muted"}}
          {{i18n "user.muted_tags"}}</label>
        <TagChooser
          @tags={{@model.muted_tags}}
          @blockedTags={{@selectedTags}}
          @everyTag={{true}}
          @unlimitedTagCount={{true}}
          @options={{hash allowAny=false}}
        />
      </div>
      <div class="instructions">{{i18n "user.muted_tags_instructions"}}</div>
    </div>

    <PluginOutlet
      @name="user-preferences-tags"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@model save=@save}}
    />
    <PluginOutlet
      @name="user-custom-controls"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@model}}
    />
  {{/if}}
</template>;

export default Tags;
