import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import FlatButton from "discourse/components/flat-button";
import concatClass from "discourse/helpers/concat-class";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const Buttons = <template>
  <StyleguideExample @title=".btn-icon - sizes (large, default, small)">
    {{#each @dummy.buttonSizes as |bs|}}
      <DButton
        @icon="xmark"
        @translatedTitle={{bs.text}}
        @disabled={{bs.disabled}}
        class={{bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title=".btn-icon - states">
    {{#each @dummy.buttonStates as |bs|}}
      <DButton
        @icon="xmark"
        @translatedTitle={{bs.text}}
        @disabled={{bs.disabled}}
        class={{bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title=".btn-text - sizes (large, default, small)">
    {{#each @dummy.buttonSizes as |bs|}}
      <DButton
        @translatedLabel={{bs.text}}
        @disabled={{bs.disabled}}
        class={{bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title=".btn-text - states">
    {{#each @dummy.buttonStates as |bs|}}
      <DButton
        @translatedLabel={{bs.text}}
        @disabled={{bs.disabled}}
        class={{bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample
    @title=".btn-default .btn-icon-text - sizes (large, default, small)"
  >
    {{#each @dummy.buttonSizes as |bs|}}
      <DButton
        @icon="plus"
        @translatedLabel={{bs.text}}
        @disabled={{bs.disabled}}
        class={{bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title=".btn-default .btn-icon-text - states">
    {{#each @dummy.buttonStates as |bs|}}
      <DButton
        @icon="plus"
        @translatedLabel={{bs.text}}
        @disabled={{bs.disabled}}
        class={{bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample
    @title=".btn-primary .btn-icon-text - sizes (large, default, small)"
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

  <StyleguideExample @title=".btn-primary .btn-icon-text - states">
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
    @title=".btn-danger .btn-icon-text - sizes (large, default, small)"
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

  <StyleguideExample @title=".btn-danger .btn-icon-text - states">
    {{#each @dummy.buttonStates as |bs|}}
      <DButton
        @icon="trash-can"
        @translatedLabel={{bs.text}}
        @disabled={{bs.disabled}}
        class={{concatClass "btn-danger" bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title=".btn-flat - sizes (large, default, small)">
    {{#each @dummy.buttonSizes as |bs|}}
      <FlatButton
        @icon="trash-can"
        @disabled={{bs.disabled}}
        @translatedTitle={{bs.title}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title=".btn-flat - states">
    {{#each @dummy.buttonStates as |bs|}}
      <FlatButton
        @icon="trash-can"
        @disabled={{bs.disabled}}
        @translatedTitle={{bs.title}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample
    @title="<DButton> btn-flat btn-text - sizes (large, default, small)"
  >
    {{#each @dummy.buttonSizes as |bs|}}
      <DButton
        @disabled={{bs.disabled}}
        @translatedLabel={{bs.text}}
        class={{concatClass "btn-flat" bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title="<DButton> btn-flat btn-text - states">
    {{#each @dummy.buttonStates as |bs|}}
      <DButton
        @disabled={{bs.disabled}}
        @translatedLabel={{bs.text}}
        class={{concatClass "btn-flat" bs.class}}
      />
    {{/each}}
  </StyleguideExample>

  <StyleguideExample @title="<DToggleSwitch>">
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
</template>;

export default Buttons;
