import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import CharCounter from "discourse/components/char-counter";
import withEventValue from "discourse/helpers/with-event-value";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class CharCounterMolecule extends Component {
  get charCounterCode() {
    return `
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import CharCounter from "discourse/components/char-counter";
import withEventValue from "discourse/helpers/with-event-value";

<template>
  <CharCounter @max="50" @value={{@dummy.charCounterContent}}>
    <textarea
      {{on "input" (withEventValue (fn (mut @dummy.charCounterContent)))}}
      class="styleguide--char-counter"
    ></textarea>
  </CharCounter>
</template>
    `;
  }

  <template>
    <StyleguideExample @title="<CharCounter>" @code={{this.charCounterCode}}>
      <CharCounter @max="50" @value={{@dummy.charCounterContent}}>
        <textarea
          {{on "input" (withEventValue (fn (mut @dummy.charCounterContent)))}}
          class="styleguide--char-counter"
        ></textarea>
      </CharCounter>
    </StyleguideExample>
  </template>
}
