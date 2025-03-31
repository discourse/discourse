import Component from "@glimmer/component";
import curryComponent from "ember-curry-component";
import List from "discourse/components/topic-list/list";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
export default class TopicListShim extends Component {
  <template>
    {{#let (curryComponent List this.args) as |curriedComponent|}}
      <curriedComponent />
    {{/let}}
  </template>
}
