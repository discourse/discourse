import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "header-user-tip-shim",
  "div.header-user-tip-shim",
  hbs`<UserTip @id="first_notification" @triggerSelector=".header-dropdown-toggle.current-user" @placement="bottom-end" @titleText={{i18n "user_tips.first_notification.title"}} @contentText={{i18n "user_tips.first_notification.content"}} />`
);
