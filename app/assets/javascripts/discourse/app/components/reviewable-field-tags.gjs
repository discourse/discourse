import Component from "@ember/component";
import { action } from "@ember/object";
import MiniTagChooser from "select-kit/components/mini-tag-chooser";
import { hash } from "@ember/helper";

export default class ReviewableFieldTags extends Component {
  @action
  onChange(tags) {
    this.set("value", tags);

    this.valueChanged &&
      this.valueChanged({
        target: {
          value: tags,
        },
      });
  }
<template><MiniTagChooser @value={{this.value}} @onChange={{action "onChange"}} @options={{hash categoryId=this.tagCategoryId}} /></template>}
