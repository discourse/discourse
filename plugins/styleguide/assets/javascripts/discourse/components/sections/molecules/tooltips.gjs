import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { TOOLTIP } from "discourse/float-kit/lib/constants";
import withEventValue from "discourse/helpers/with-event-value";
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
  @tracked inline = TOOLTIP.options.inline || false;
  @tracked interactive = TOOLTIP.options.interactive;
  @tracked maxWidth = TOOLTIP.options.maxWidth;
  @tracked identifier = null;
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

  get tooltipCode() {
    const contentValue = this._content.toString().replace(/"/g, '\\"');

    return `
import DTooltip from "discourse/float-kit/components/d-tooltip";

<template>
  <DTooltip
    @label="${this.label}"
    @offset={{${this.offset}}}
    @arrow={{${this.arrow}}}
    @maxWidth={{${this.maxWidth}}}
    @identifier={{${this.identifier}}}
    @interactive={{${this.interactive}}}
    @triggers="${this.triggers}"
    @untriggers="${this.untriggers}"
    @content="${contentValue}"
    @inline={{${this.inline}}}
  />
</template>
    `.trim();
  }

  get tooltipBlocksCode() {
    const contentValue = this._content.toString().replace(/"/g, '\\"');

    return `
import DTooltip from "discourse/float-kit/components/d-tooltip";

<template>
  <DTooltip
    @offset={{${this.offset}}}
    @arrow={{${this.arrow}}}
    @maxWidth={{${this.maxWidth}}}
    @identifier={{${this.identifier}}}
    @interactive={{${this.interactive}}}
    @triggers="${this.triggers}"
    @untriggers="${this.untriggers}"
    @content="${contentValue}"
    @inline={{${this.inline}}}
  >
    <:trigger>
      ${this.label}
    </:trigger>
    <:content>
      ${contentValue}
    </:content>
  </DTooltip>
</template>
    `.trim();
  }

  get tooltipServiceCode() {
    const contentValue = this._content.toString().replace(/"/g, '\\"');

    return `
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class MyComponent extends Component {
  @service tooltip;

  @action
  registerTooltip() {
    this.tooltip.register(
      document.querySelector("#tooltip-instance"),
      {
        offset: ${this.offset},
        arrow: ${this.arrow},
        maxWidth: ${this.maxWidth},
        identifier: ${this.identifier},
        interactive: ${this.interactive},
        triggers: "${this.triggers}",
        untriggers: "${this.untriggers}",
        content: "${contentValue}",
      }
    );
  }
}

<template>
  <span id="tooltip-instance">${this.label}</span>
  <DButton @action={{this.registerTooltip}}>Register</DButton>
</template>
    `.trim();
  }

  get tooltipServiceComponentCode() {
    const contentValue = this._content.toString().replace(/"/g, '\\"');

    return `
import { action } from "@ember/object";
import { service } from "@ember/service";
import DummyComponent from "path/to/dummy-component";

export default class MyComponent extends Component {
  @service tooltip;

  @action
  registerTooltipWithComponent() {
    this.tooltip.register(
      document.querySelector("#tooltip-instance-with-component"),
      {
        offset: ${this.offset},
        arrow: ${this.arrow},
        maxWidth: ${this.maxWidth},
        identifier: ${this.identifier},
        interactive: ${this.interactive},
        triggers: "${this.triggers}",
        untriggers: "${this.untriggers}",
        content: "${contentValue}",
        component: DummyComponent,
        data: { foo: 1 },
      }
    );
  }
}

<template>
  <span id="tooltip-instance-with-component">${this.label}</span>
  <DButton @action={{this.registerTooltipWithComponent}}>Register</DButton>
</template>
    `.trim();
  }

  <template>
    <StyleguideExample
      @title="DTooltip - with @label"
      @code={{this.tooltipCode}}
    >
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
    </StyleguideExample>

    <StyleguideExample
      @title="DTooltip - with named blocks"
      @code={{this.tooltipBlocksCode}}
    >
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
    </StyleguideExample>

    <StyleguideExample
      @title="Tooltip Service"
      @code={{this.tooltipServiceCode}}
    >
      <StyleguideComponent @tag="tooltip service">
        <:sample>
          <span id="tooltip-instance">{{this.label}}</span>
        </:sample>
        <:actions>
          <DButton @action={{this.registerTooltip}}>Register</DButton>
        </:actions>
      </StyleguideComponent>
    </StyleguideExample>

    <StyleguideExample
      @title="Tooltip Service - with component"
      @code={{this.tooltipServiceComponentCode}}
    >
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
    </StyleguideExample>

    <Controls>
      <Row @name="Example label">
        <input
          {{on "input" (withEventValue (fn (mut this.label)))}}
          type="text"
          value={{this.label}}
        />
      </Row>
      <Row @name="[@content]">
        <input
          {{on "input" (withEventValue (fn (mut this.content)))}}
          type="text"
          value={{this.content}}
        />
      </Row>
      <Row @name="[@identifier]">
        <input
          {{on "input" (withEventValue (fn (mut this.identifier)))}}
          type="text"
          value={{this.identifier}}
        />
      </Row>
      <Row @name="[@offset]">
        <input
          {{on "input" (withEventValue (fn (mut this.offset)))}}
          type="number"
          value={{this.offset}}
        />
      </Row>
      <Row @name="[@triggers]">
        <input
          {{on "input" (withEventValue (fn (mut this.triggers)))}}
          type="text"
          value={{this.triggers}}
        />
      </Row>
      <Row @name="[@untriggers]">
        <input
          {{on "input" (withEventValue (fn (mut this.untriggers)))}}
          type="text"
          value={{this.untriggers}}
        />
      </Row>
      <Row @name="[@maxWidth]">
        <input
          {{on "input" (withEventValue (fn (mut this.maxWidth)))}}
          type="number"
          value={{this.maxWidth}}
        />
      </Row>
      <Row @name="[@interactive]">
        <DToggleSwitch
          @state={{this.interactive}}
          {{on "click" this.toggleInteractive}}
        />
      </Row>
      <Row @name="[@arrow]">
        <DToggleSwitch @state={{this.arrow}} {{on "click" this.toggleArrow}} />
      </Row>
      <Row @name="[@inline]">
        <DToggleSwitch
          @state={{this.inline}}
          {{on "click" this.toggleInline}}
        />
      </Row>
    </Controls>
  </template>
}
