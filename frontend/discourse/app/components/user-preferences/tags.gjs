import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { i18n } from "discourse-i18n";

const Tags = <template>
  <@form.Field
    @name="watched_tags"
    @title={{i18n "user.watched_tags"}}
    @format="large"
    @description={{i18n "user.watched_tags_instructions"}}
    as |field|
  >
    <field.Custom>
      <TagChooser
        @tags={{field.value}}
        @blockedTags={{@selectedTags}}
        @everyTag={{true}}
        @unlimitedTagCount={{true}}
        @options={{hash allowAny=false}}
        @onChange={{field.set}}
      />

    </field.Custom>
  </@form.Field>

  <@form.Field
    @name="tracked_tags"
    @title={{i18n "user.tracked_tags"}}
    @format="large"
    @description={{i18n "user.tracked_tags_instructions"}}
    as |field|
  >
    <field.Custom>

      <TagChooser
        @tags={{field.value}}
        @blockedTags={{@selectedTags}}
        @everyTag={{true}}
        @unlimitedTagCount={{true}}
        @options={{hash allowAny=false}}
        @onChange={{field.set}}
      />

    </field.Custom>
  </@form.Field>

  <@form.Field
    @name="watching_first_post_tags"
    @title={{i18n "user.watched_first_post_tags"}}
    @format="large"
    @description={{i18n "user.watched_first_post_tags_instructions"}}
    as |field|
  >
    <field.Custom>

      <TagChooser
        @tags={{field.value}}
        @blockedTags={{@selectedTags}}
        @everyTag={{true}}
        @unlimitedTagCount={{true}}
        @options={{hash allowAny=false}}
        @onChange={{field.set}}
      />

    </field.Custom>
  </@form.Field>

  <@form.Field
    @name="muted_tags"
    @title={{i18n "user.muted_tags"}}
    @format="large"
    @description={{i18n "user.muted_tags_instructions"}}
    as |field|
  >
    <field.Custom>

      <TagChooser
        @tags={{field.value}}
        @blockedTags={{@selectedTags}}
        @everyTag={{true}}
        @unlimitedTagCount={{true}}
        @options={{hash allowAny=false}}
        @onChange={{field.set}}
      />

    </field.Custom>
  </@form.Field>

  <PluginOutlet
    @name="user-preferences-tags"
    @connectorTagName="div"
    @outletArgs={{lazyHash model=@model form=@form}}
  />
  <PluginOutlet
    @name="user-custom-controls"
    @connectorTagName="div"
    @outletArgs={{lazyHash model=@model}}
  />
</template>;

export default Tags;
