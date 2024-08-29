import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

// TODO deprecate for the Glimmer Post Menu

registerWidgetShim(
  "post-user-tip-shim",
  "div.post-user-tip-shim",
  hbs`<UserTip
    @id="post_menu"
    @triggerSelector=".post-controls .actions .show-more-actions"
    @placement="top"
    @titleText={{i18n "user_tips.post_menu.title"}}
    @contentText={{i18n "user_tips.post_menu.content"}}
    @priority={{600}}
  />`
);
