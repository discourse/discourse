import Component from "@glimmer/component";
import curryComponent from "ember-curry-component";
import List from "discourse/components/topic-list/list";
import deprecated from "discourse/lib/deprecated";

export default class TopicListShim extends Component {
  constructor() {
    super(...arguments);
    deprecated(
      `components/topic-list is deprecated, and should be replaced with components/topics-list/list`,
      { id: "discourse.legacy-topic-list" }
    );
  }

  <template>
    {{#let (curryComponent List this.args) as |CurriedComponent|}}
      <CurriedComponent ...attributes />
    {{/let}}
  </template>
}
