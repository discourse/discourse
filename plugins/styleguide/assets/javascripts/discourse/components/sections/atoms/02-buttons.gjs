import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import concatClass from "discourse/helpers/concat-class";
import { not } from "discourse/truth-helpers";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Buttons extends Component {
  get btnIconSizesCode() {
    return `
import DButton from "discourse/components/d-button";

// Size classes: btn-large, btn-default, btn-small
<template>
  <DButton @icon="xmark" @disabled={{false}} class={{this.class}}/>
</template>
    `;
  }

  get btnIconStatesCode() {
    return `
import DButton from "discourse/components/d-button";

// Available states: normal, hover, disabled
<template>
  <DButton @icon="xmark" @disabled={{false}} class={{this.class}}/>
</template>
    `;
  }

  get btnTextSizesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonSizes as |bs|}}
    <DButton
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-default" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnTextStatesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-default" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnDefaultIconTextSizesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonSizes as |bs|}}
    <DButton
      @icon="plus"
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-default" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnDefaultIconTextStatesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @icon="plus"
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-default" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnPrimaryIconTextSizesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonSizes as |bs|}}
    <DButton
      @icon="plus"
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-primary" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnPrimaryIconTextStatesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @icon="plus"
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-primary" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnDangerIconTextSizesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonSizes as |bs|}}
    <DButton
      @icon="trash-can"
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-danger" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnDangerIconTextStatesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @icon="trash-can"
      @translatedLabel={{bs.text}}
      @disabled={{bs.disabled}}
      class={{concatClass "btn-danger" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnFlatSizesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonSizes as |bs|}}
    <DButton
      @icon="trash-can"
      @disabled={{bs.disabled}}
      @translatedTitle={{bs.title}}
      class={{concatClass "btn-flat" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnFlatStatesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @icon="trash-can"
      @disabled={{bs.disabled}}
      @translatedLabel={{bs.text}}
      class={{concatClass "btn-flat" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get btnTransparentStatesCode() {
    return `
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @icon="trash-can"
      @disabled={{bs.disabled}}
      @translatedLabel={{bs.text}}
      class={{concatClass "btn-transparent" bs.class}}
    />
  {{/each}}
</template>
    `;
  }

  get buttonLinkCode() {
    return `
import DButton from "discourse/components/d-button";

<template>
  {{#each @dummy.buttonStates as |bs|}}
    <DButton
      @icon="trash-can"
      @translatedLabel={{bs.text}}
      @display="link"
      class={{bs.class}}
      @disabled={{bs.disabled}}
    />
  {{/each}}
</template>
    `;
  }

  get toggleSwitchCode() {
    return `
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { not } from "discourse/truth-helpers";

<template>
  <DToggleSwitch
    @state={{@dummy.toggleSwitchState}}
    {{on
      "click"
      (fn (mut @dummy.toggleSwitchState) (not @dummy.toggleSwitchState))
    }}
  />
  <DToggleSwitch
    disabled="true"
    @state={{true}}
    title="Disabled with state=true"
  />
  <DToggleSwitch
    disabled="true"
    @state={{false}}
    title="Disabled with state=false"
  />
</template>
    `;
  }

  <template>
    {{this.availableSizes}}

    <StyleguideExample
      @title="DButton - icon only - sizes (large, default, small)"
      @code={{this.btnIconSizesCode}}
    >
      {{#each @dummy.buttonSizes as |bs|}}
        <DButton
          @icon="xmark"
          @translatedTitle={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-default" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon only - states"
      @code={{this.btnIconStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="xmark"
          @translatedTitle={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-default" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - text only - sizes (large, default, small)"
      @code={{this.btnTextSizesCode}}
    >
      {{#each @dummy.buttonSizes as |bs|}}
        <DButton
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-default" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - text only - states"
      @code={{this.btnTextStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-default" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon and text - sizes (large, default, small)"
      @code={{this.btnDefaultIconTextSizesCode}}
    >
      {{#each @dummy.buttonSizes as |bs|}}
        <DButton
          @icon="plus"
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-default" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon and text - states"
      @code={{this.btnDefaultIconTextStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="plus"
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-default" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon and text - sizes"
      @code={{this.btnPrimaryIconTextSizesCode}}
    >
      {{#each @dummy.buttonSizes as |bs|}}
        <DButton
          @icon="plus"
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-primary" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon and text - btn-primary - states"
      @code={{this.btnPrimaryIconTextStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="plus"
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-primary" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon and text - btn-danger - sizes"
      @code={{this.btnDangerIconTextSizesCode}}
    >
      {{#each @dummy.buttonSizes as |bs|}}
        <DButton
          @icon="trash-can"
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-danger" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - icon and text - btn-danger - states"
      @code={{this.btnDangerIconTextStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="trash-can"
          @translatedLabel={{bs.text}}
          @disabled={{bs.disabled}}
          class={{concatClass "btn-danger" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - btn-flat - icon only - sizes"
      @code={{this.btnFlatSizesCode}}
    >
      {{#each @dummy.buttonSizes as |bs|}}
        <DButton
          @icon="trash-can"
          @disabled={{bs.disabled}}
          @translatedTitle={{bs.title}}
          class={{concatClass "btn-flat" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - btn-flat - states"
      @code={{this.btnFlatStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="trash-can"
          @disabled={{bs.disabled}}
          @translatedLabel={{bs.text}}
          class={{concatClass "btn-flat" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample
      @title="DButton - btn-transparent - states"
      @code={{this.btnTransparentStatesCode}}
    >
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="trash-can"
          @disabled={{bs.disabled}}
          @translatedLabel={{bs.text}}
          class={{concatClass "btn-transparent" bs.class}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample @title="DButton - link" @code={{this.buttonLinkCode}}>
      {{#each @dummy.buttonStates as |bs|}}
        <DButton
          @icon="trash-can"
          @translatedLabel={{bs.text}}
          @display="link"
          class={{bs.class}}
          @disabled={{bs.disabled}}
        />
      {{/each}}
    </StyleguideExample>

    <StyleguideExample @title="DToggleSwitch" @code={{this.toggleSwitchCode}}>
      <DToggleSwitch
        @state={{@dummy.toggleSwitchState}}
        {{on
          "click"
          (fn (mut @dummy.toggleSwitchState) (not @dummy.toggleSwitchState))
        }}
      />
      <DToggleSwitch
        disabled="true"
        @state={{true}}
        title="Disabled with state=true"
      />
      <DToggleSwitch
        disabled="true"
        @state={{false}}
        title="Disabled with state=false"
      />
    </StyleguideExample>
  </template>
}
