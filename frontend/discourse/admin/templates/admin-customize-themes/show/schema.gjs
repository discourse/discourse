import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import Editor from "discourse/admin/components/schema-setting/editor";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="customize-show-schema__header row">
    <LinkTo
      class="btn-transparent customize-show-schema__back"
      @model={{@model.theme.id}}
      @route="adminCustomizeThemes.show"
    >
      {{dIcon "arrow-left"}}{{@model.theme.name}}
    </LinkTo>
    <h2>
      {{i18n "admin.customize.schema.title" (hash name=@model.setting.setting)}}
    </h2>
  </div>

  <Editor
    @id={{@model.theme.id}}
    @routeToRedirect="adminCustomizeThemes.show"
    @schema={{@model.setting.objects_schema}}
    @setting={{@model.setting}}
  />
</template>
