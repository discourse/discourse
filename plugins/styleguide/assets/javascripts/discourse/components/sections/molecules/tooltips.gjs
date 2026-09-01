import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { TOOLTIP } from "discourse/float-kit/lib/constants";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
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

  get content() {
    return this._content;
  }

  set content(value) {
    this._content = trustHTML(value);
  }

  get triggersByDevice() {
    return this.site.mobileView ? "mobile" : "desktop";
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

  // These samples are curated rather than sourced from a module: each bakes in
  // the current value of the controls panel, so it changes as the reader edits
  // it and no static module could express it.
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

  <template>
    <StyleguideExample
      @code={{this.tooltipCode}}
      @title="DTooltip - with @label"
    >
      <StyleguideComponent @tag="tooltip component">
        <:sample>
          <DTooltip
            @arrow={{this.arrow}}
            @content={{this.content}}
            @identifier={{this.identifier}}
            @inline={{this.inline}}
            @interactive={{this.interactive}}
            @label={{this.label}}
            @maxWidth={{this.maxWidth}}
            @offset={{this.offset}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
          />
        </:sample>
      </StyleguideComponent>
    </StyleguideExample>

    <StyleguideExample
      @code={{this.tooltipBlocksCode}}
      @title="DTooltip - with named blocks"
    >
      <StyleguideComponent @tag="tooltip component">
        <:sample>
          <DTooltip
            @arrow={{this.arrow}}
            @content={{this.content}}
            @identifier={{this.identifier}}
            @inline={{this.inline}}
            @interactive={{this.interactive}}
            @maxWidth={{this.maxWidth}}
            @offset={{this.offset}}
            @triggers={{this.triggers}}
            @untriggers={{this.untriggers}}
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
      @code={{this.tooltipServiceCode}}
      @title="Tooltip Service"
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
      @code={{this.tooltipServiceComponentCode}}
      @title="Tooltip Service - with component"
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
          type="text"
          value={{this.label}}
          {{on "input" (withEventValue (fn (mut this.label)))}}
        />
      </Row>
      <Row @name="[@content]">
        <input
          type="text"
          value={{this.content}}
          {{on "input" (withEventValue (fn (mut this.content)))}}
        />
      </Row>
      <Row @name="[@identifier]">
        <input
          type="text"
          value={{this.identifier}}
          {{on "input" (withEventValue (fn (mut this.identifier)))}}
        />
      </Row>
      <Row @name="[@offset]">
        <input
          type="number"
          value={{this.offset}}
          {{on "input" (withEventValue (fn (mut this.offset)))}}
        />
      </Row>
      <Row @name="[@triggers]">
        <input
          type="text"
          value={{this.triggers}}
          {{on "input" (withEventValue (fn (mut this.triggers)))}}
        />
      </Row>
      <Row @name="[@untriggers]">
        <input
          type="text"
          value={{this.untriggers}}
          {{on "input" (withEventValue (fn (mut this.untriggers)))}}
        />
      </Row>
      <Row @name="[@maxWidth]">
        <input
          type="number"
          value={{this.maxWidth}}
          {{on "input" (withEventValue (fn (mut this.maxWidth)))}}
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
