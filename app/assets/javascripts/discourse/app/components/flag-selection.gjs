import Component from "@ember/component";
import { next } from "@ember/runloop";
import { observes } from "@ember-decorators/object";

// Mostly hacks because `flag.hbs` didn't use `radio-button`
import i18n from "discourse/helpers/i18n";
export default class FlagSelection extends Component {
  _selectRadio() {
    this.element.querySelector("input[type='radio']").checked = false;

    const nameKey = this.nameKey;
    if (!nameKey) {
      return;
    }

    const selector = this.element.querySelector("#radio_" + nameKey);
    if (selector) {
      selector.checked = "true";
    }
  }

  @observes("nameKey")
  selectedChanged() {
    next(this, this._selectRadio);
  }
<template>{{#each this.flags as |f|}}
  {{yield f}}
{{else}}
  {{i18n "flagging.cant"}}
{{/each}}</template>}
