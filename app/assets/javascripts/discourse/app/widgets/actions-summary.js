import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

// This shim is nesting everything into a DIV and changing the HTML but only thw two voting plugins
// are using this widget outside of core.
registerWidgetShim(
  "small-user-list",
  "div",
  hbs`
    <SmallUserList class={{@data.listClassName}}
                   @ariaLabel={{@data.ariaLabel}}
                   @users={{@data.users}}
                   @addSelf={{@data.addSelf}}
                   @count={{@data.count}}
                   @description={{@data.description}}/>`
);

registerWidgetShim(
  "actions-summary",
  "section.post-actions",
  hbs`
    <ActionsSummary @data={{@data}} /> `
);
