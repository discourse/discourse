import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "float-kit/components/d-tooltip";
import { TOOLTIP } from "float-kit/lib/constants";
import DummyComponent from "discourse/plugins/styleguide/discourse/components/dummy-component";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

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

  <template>
    <StyleguideExample @title="<DTooltip />">
      <StyleguideComponent @tag="tooltip component">
        <:sample>
          <DTooltip
            @label={{this.label}}
            @offset={{this.offset}}
            @arrow={{this.arrow}}
            @maxWidth={{this.maxWidth}}
            @identifier={{this.identifier}}
            @interactive={{this.interactive}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
            @content={{this.content}}
            @inline={{this.inline}}
          />
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="tooltip component">
        <:sample>
          <DTooltip
            @offset={{this.offset}}
            @arrow={{this.arrow}}
            @maxWidth={{this.maxWidth}}
            @identifier={{this.identifier}}
            @interactive={{this.interactive}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
            @content={{this.content}}
            @inline={{this.inline}}
          >
            <:trigger>
              {{this.label}}
            </:trigger>
            <:content>
              {{this.content}}
            </:content>
          </DTooltip>
        </:sample>
      </StyleguideComponent>

      <StyleguideComponent @tag="tooltip service">
        <:sample>
          <span id="tooltip-instance">{{this.label}}</span>
        </:sample>
        <:actions>
          <DButton @action={{this.registerTooltip}}>Register</DButton>
        </:actions>
      </StyleguideComponent>

      <StyleguideComponent @tag="tooltip service">
        <:sample>
          <span id="tooltip-instance-with-component">{{this.label}}</span>
        </:sample>
        <:actions>
          <DButton
            @action={{this.registerTooltipWithComponent}}
          >Register</DButton>
        </:actions>
      </StyleguideComponent>

      <Controls>
        <Row @name="Example label">
          <Input @value={{this.label}} />
        </Row>
        <Row @name="[@content]">
          <Input @value={{this.content}} />
        </Row>
        <Row @name="[@identifier]">
          <Input @value={{this.identifier}} />
        </Row>
        <Row @name="[@offset]">
          <Input @value={{this.offset}} @type="number" />
        </Row>
        <Row @name="[@triggers]">
          <Input @value={{this.triggers}} />
        </Row>
        <Row @name="[@untriggers]">
          <Input @value={{this.untriggers}} />
        </Row>
        <Row @name="[@maxWidth]">
          <Input @value={{this.maxWidth}} @type="number" />
        </Row>
        <Row @name="[@interactive]">
          <DToggleSwitch
            @state={{this.interactive}}
            {{on "click" this.toggleInteractive}}
          />
        </Row>
        <Row @name="[@arrow]">
          <DToggleSwitch
            @state={{this.arrow}}
            {{on "click" this.toggleArrow}}
          />
        </Row>
        <Row @name="[@inline]">
          <DToggleSwitch
            @state={{this.inline}}
            {{on "click" this.toggleInline}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
