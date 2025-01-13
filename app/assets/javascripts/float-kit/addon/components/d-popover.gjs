import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import deprecated from "discourse/lib/deprecated";

export default class DPopover extends Component {
  @service tooltip;

  registerDTooltip = modifier((element) => {
    deprecated(
      "`<DPopover />` is deprecated. Use `<DTooltip />` or the `tooltip` service instead.",
      { id: "discourse.d-popover" }
    );

    const trigger = element.children[0];
    const content = element.children[1];

    if (!trigger || !content) {
      return;
    }

    const instance = this.tooltip.register(trigger, {
      content,
    });

    content.remove();

    return () => {
      instance.destroy();
    };
  });

  <template>
    <div style="display:inline-flex;" {{this.registerDTooltip}}>
      {{yield}}
    </div>
  </template>
}
