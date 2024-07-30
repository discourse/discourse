import { hbs } from "ember-cli-htmlbars";
import RenderGlimmer, {
  registerWidgetShim,
} from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";

createWidget("small-user-list", {
  tagName: "div.clearfix.small-user-list",

  buildClasses(atts) {
    return atts.listClassName;
  },

  buildAttributes(attrs) {
    const attributes = { role: "list" };
    if (attrs.ariaLabel) {
      attributes["aria-label"] = attrs.ariaLabel;
    }
    return attributes;
  },

  html(attrs) {
    return [
      new RenderGlimmer(
        this,
        "span.small-user-list-content",
        hbs`<SmallUserList @data={{@data.attrs}}/>`,
        {
          attrs,
        }
      ),
    ];
  },
});

registerWidgetShim(
  "actions-summary",
  "section.post-actions",
  hbs`<ActionsSummary @data={{@data}} /> `
);
