import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { i18n } from "discourse-i18n";

export default class NestedRepliesSettings extends Component {
  static shouldRender(args, context) {
    return (
      context.siteSettings.nested_replies_enabled &&
      !context.siteSettings.enable_simplified_category_creation
    );
  }

  <template>
    <section class="field">
      <h3>{{i18n "nested_replies.nested_view"}}</h3>
      <div class="enable-nested-replies-default">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{@outletArgs.category.category_setting.nested_replies_default}}
          />
          {{i18n "nested_replies.category_settings.default_nested_view"}}
        </label>
      </div>
    </section>
  </template>
}
