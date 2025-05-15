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
        @route="adminCustomizeThemes.show"
        @model={{@model.theme.id}}
        class="btn-transparent customize-show-schema__back"
      >
        {{icon "arrow-left"}}{{@model.theme.name}}
      </LinkTo>
      <h2>
        {{i18n
          "admin.customize.schema.title"
          (hash name=@model.setting.setting)
        }}
      </h2>
    </div>

    <Editor
      @id={{@model.theme.id}}
      @routeToRedirect="adminCustomizeThemes.show"
      @schema={{@model.setting.objects_schema}}
      @setting={{@model.setting}}
    />
  </template>
);
