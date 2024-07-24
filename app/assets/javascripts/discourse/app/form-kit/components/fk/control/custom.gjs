import Component from "@glimmer/component";

export default class FKControlToggle extends Component {
  static controlType = "custom";

  <template>
    {{yield}}
  </template>
}
