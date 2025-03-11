import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import { hash } from "@ember/helper";
import formatDate from "discourse/helpers/format-date";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import htmlSafe from "discourse/helpers/html-safe";

@tagName("li")
export default class UserSummaryTopic extends Component {<template><PluginOutlet @name="user-summary-topic-wrapper" @outletArgs={{hash topic=@topic url=@url}}>
  <span class="topic-info">
    {{formatDate @createdAt format="tiny" noTitle="true"}}
    {{#if @likes}}
      &middot;
      {{icon "heart"}}&nbsp;<span class="like-count">{{number @likes}}</span>
    {{/if}}
  </span>
  <br />
  <a href={{@url}}>{{htmlSafe @topic.fancyTitle}}</a>
</PluginOutlet></template>}
