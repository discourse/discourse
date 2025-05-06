import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import Editor, {
  SCHEMA_MODES,
} from "admin/components/schema-theme-setting/editor";

export default RouteTemplate(
  <template>
    <div class="customize-themes-show-schema__header row">
      <LinkTo
        @route="adminPlugins.show.settings"
        @model={{@model.plugin.id}}
        class="btn-transparent customize-themes-show-schema__back"
      >
        {{icon "arrow-left"}}{{@model.plugin.name}}
      </LinkTo>
      <h2>
        {{i18n
          "admin.customize.theme.schema.title"
          (hash name=@model.settingName)
        }}
      </h2>
    </div>

    <Editor
      @schemaMode={{SCHEMA_MODES.PLUGIN}}
      @settingName={{@model.setting.setting}}
      @pluginId={{@model.plugin.id}}
      @setting={{@model.setting}}
    />
  </template>
);
