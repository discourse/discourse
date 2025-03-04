import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";

@tagName("div")
export default class IgnoredUserListItem extends Component {<template><div class="ignored-user-list-item">
  <span class="ignored-user-name">{{this.item}}</span>
  <DButton @action={{fn (action "removeIgnoredUser") this.item}} @icon="xmark" class="remove-ignored-user no-text btn-icon" />
</div></template>
  items = null;

  @action
  removeIgnoredUser(item) {
    this.onRemoveIgnoredUser(item);
  }
}
