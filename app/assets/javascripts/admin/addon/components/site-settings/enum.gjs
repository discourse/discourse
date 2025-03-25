import Component from "@ember/component";
import ComboBox from "select-kit/components/combo-box";
import { fn, hash } from "@ember/helper";

export default class Enum extends Component {<template><ComboBox @content={{this.setting.validValues}} @value={{this.value}} @onChange={{fn (mut this.value)}} @valueProperty={{this.setting.computedValueProperty}} @nameProperty={{this.setting.computedNameProperty}} @options={{hash castInteger=true allowAny=this.setting.allowsNone}} />

{{this.preview}}</template>}
