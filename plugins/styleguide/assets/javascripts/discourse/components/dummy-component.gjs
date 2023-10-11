import Component from "@glimmer/component";

export default class DummyComponent extends Component {
  <template>
    My custom component with foo: {{@model.foo}}
  </template>
}
