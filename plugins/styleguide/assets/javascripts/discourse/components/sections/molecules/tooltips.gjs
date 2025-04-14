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

<StyleguideExample @title="<DTooltip />">
  <Styleguide::Component @tag="tooltip component">
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
  </Styleguide::Component>

  <Styleguide::Component @tag="tooltip component">
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
  </Styleguide::Component>

  <Styleguide::Component @tag="tooltip service">
    <:sample>
      <span id="tooltip-instance">{{this.label}}</span>
    </:sample>
    <:actions>
      <DButton @action={{this.registerTooltip}}>Register</DButton>
    </:actions>
  </Styleguide::Component>

  <Styleguide::Component @tag="tooltip service">
    <:sample>
      <span id="tooltip-instance-with-component">{{this.label}}</span>
    </:sample>
    <:actions>
      <DButton @action={{this.registerTooltipWithComponent}}>Register</DButton>
    </:actions>
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Example label">
      <Input @value={{this.label}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@content]">
      <Input @value={{this.content}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@identifier]">
      <Input @value={{this.identifier}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@offset]">
      <Input @value={{this.offset}} @type="number" />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@triggers]">
      <Input @value={{this.triggers}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@untriggers]">
      <Input @value={{this.untriggers}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@maxWidth]">
      <Input @value={{this.maxWidth}} @type="number" />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@interactive]">
      <DToggleSwitch
        @state={{this.interactive}}
        {{on "click" this.toggleInteractive}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@arrow]">
      <DToggleSwitch @state={{this.arrow}} {{on "click" this.toggleArrow}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@inline]">
      <DToggleSwitch @state={{this.inline}} {{on "click" this.toggleInline}} />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>