import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import Editor from "admin/components/schema-setting/editor";

export default RouteTemplate(
  <template>
    <div class="customize-show-schema__header row">
      <LinkTo
        @route="adminPlugins.show.settings"
        @model={{@model.plugin.id}}
        class="btn-transparent customize-show-schema__back"
      >
        {{icon "arrow-left"}}{{@model.plugin.name}}
      </LinkTo>
      <h2>
        {{i18n
          "admin.customize.schema.title"
          (hash name=@model.settingName)
        }}
      </h2>
    </div>

    <Editor
      @id={{@model.plugin.id}}
      @routeToRedirect="adminPlugins.show.settings"
      @schema={{@model.setting.schema}}
      @setting={{@model.setting}}
    />
  </template>
);
