import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import avatar from "discourse/helpers/avatar";
import { on } from "@ember/modifier";
import dIcon from "discourse/helpers/d-icon";

@classNames("item")
export default class GroupMember extends Component {<template><a href={{this.member.adminPath}}>
  {{avatar this.member imageSize="small"}}
</a>
<span>{{this.member.username}}</span>
{{#unless this.automatic}}
  <a href {{on "click" this.remove}} class="remove">
    {{dIcon "xmark"}}
  </a>
{{/unless}}</template>
  @action
  remove(event) {
    event?.preventDefault();
    this.removeAction(this.member);
  }
}
