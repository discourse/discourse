import { createWidget } from "discourse/widgets/widget";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { hbs } from "ember-cli-htmlbars";

export default createWidget("chat-header-icon", {
  tagName: "li.header-dropdown-toggle.chat-header-icon",
  title: "chat.title_capitalized",

  services: ["chat"],

  html() {
    if (!this.chat.userCanChat) {
      return;
    }

    return [
      new RenderGlimmer(
        this,
        "div.widget-component-connector",
        hbs`<Chat::Header::Icon />`
      ),
    ];
  },
});
