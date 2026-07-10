import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import type TooltipService from "discourse/float-kit/services/tooltip";
import deprecated from "discourse/lib/deprecated";

interface DPopoverSignature {
  Blocks: { default: [] };
}

export default class DPopover extends Component<DPopoverSignature> {
  @service declare tooltip: TooltipService;

  registerDTooltip = modifier((element: HTMLElement) => {
    deprecated(
      "`<DPopover />` is deprecated. Use `<DTooltip />` or the `tooltip` service instead.",
      { id: "discourse.d-popover" }
    );

    const trigger = element.children[0];
    const content = element.children[1];

    if (!trigger || !content) {
      return;
    }

    // The deprecated popover hands the tooltip a detached DOM node as its content,
    // which the option bag types as a renderable `string`; cast at this boundary.
    const instance = this.tooltip.register(trigger, {
      content: content as unknown as string,
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
