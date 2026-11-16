import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class ChatDiscoverableField extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.chat_enabled;
  }

  <template>
    <@outletArgs.form.Field
      @format="large"
      @name="chat_discoverable"
      @title={{i18n "chat.admin.bot_discoverability.description"}}
      @type="checkbox"
      as |field|
    >
      <field.Control />
    </@outletArgs.form.Field>
  </template>
}
