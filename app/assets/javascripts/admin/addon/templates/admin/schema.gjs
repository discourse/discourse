import { hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import Editor from "admin/components/schema-setting/editor";

export default RouteTemplate(
  <template>
    <div class="customize-show-schema__header row">
      <a href={{@model.goBackUrl}}>
        {{icon "arrow-left"}}
      </a>
      <h2>
        {{i18n "admin.customize.schema.title" (hash name=@model.settingName)}}
      </h2>
    </div>

    <Editor
      @id={{@model.settingName}}
      @routeToRedirect={{@model.goBackUrl}}
      @schema={{@model.setting.schema}}
      @setting={{@model.setting}}
    />
  </template>
);
