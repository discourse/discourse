import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TOOLTIP } from "float-kit/lib/constants";
import DummyComponent from "discourse/plugins/styleguide/discourse/components/dummy-component";

export default class Tooltips extends Component {
  @service tooltip;
  @service site;

  @tracked label = "What is this?";
  @tracked triggers = TOOLTIP.options.triggers[this.triggersByDevice];
  @tracked untriggers = TOOLTIP.options.untriggers[this.triggersByDevice];
  @tracked arrow = TOOLTIP.options.arrow;
  @tracked inline = TOOLTIP.options.inline;
  @tracked interactive = TOOLTIP.options.interactive;
  @tracked maxWidth = TOOLTIP.options.maxWidth;
  @tracked identifier;
  @tracked offset = TOOLTIP.options.offset;
  @tracked _content = "Hello World!";

  get triggersByDevice() {
    return this.site.mobileView ? "mobile" : "desktop";
  }

  get content() {
    return this._content;
  }

  set content(value) {
    this._content = htmlSafe(value);
  }

  get templateCode() {
    return `<DTooltip
  @label="${this.label}"
  @content="${this.content}"
/>`;
  }

  get templateCodeContent() {
    return `<DTooltip @maxWidth={{100}}>
  <:trigger>
     ${this.label}
  </:trigger>
  <:content>
    ${this.content}
  </:content>
</DTooltip>`;
  }

  get serviceCode() {
    return `this.tooltip.register(
  document.queryselector(".my-element"),
  { content: "${this.content}" }
);`;
  }

  get serviceCodeComponent() {
    return `this.tooltip.register(
  document.queryselector(".my-element"),
  { component: MyComponent, data: { foo: 1 } }
);`;
  }

  @action
  toggleArrow() {
    this.arrow = !this.arrow;
  }

  @action
  toggleInteractive() {
    this.interactive = !this.interactive;
  }

  @action
  toggleInline() {
    this.inline = !this.inline;
  }

  @action
  registerTooltip() {
    this.tooltipInstance?.destroy();
    this.tooltipInstance = this.tooltip.register(
      document.querySelector("#tooltip-instance"),
      this.options
    );
  }

  @action
  registerTooltipWithComponent() {
    this.tooltipInstanceWithComponent?.destroy();
    this.tooltipInstanceWithComponent = this.tooltip.register(
      document.querySelector("#tooltip-instance-with-component"),
      {
        ...this.options,
        component: DummyComponent,
        data: { foo: 1 },
      }
    );
  }

  get options() {
    return {
      offset: this.offset,
      arrow: this.arrow,
      maxWidth: this.maxWidth,
      identifier: this.identifier,
      interactive: this.interactive,
      triggers: this.triggers,
      untriggers: this.untriggers,
      content: this.content,
    };
  }
}
