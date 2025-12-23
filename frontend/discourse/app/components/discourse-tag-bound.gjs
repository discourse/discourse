/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import getURL from "discourse/lib/get-url";

@tagName("a")
@classNameBindings(":discourse-tag", "style", "tagClass")
@attributeBindings("href")
export default class DiscourseTagBound extends Component {
  @computed("tagRecord.id")
  get tagClass() {
    return "tag-" + this.tagRecord?.id;
  }

  @computed("tagRecord.id")
  get href() {
    return getURL("/tag/" + this.tagRecord?.id);
  }

  <template>{{this.tagRecord.id}}</template>
}
