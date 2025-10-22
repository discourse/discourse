import Component from "@glimmer/component";

export default class FKControlCustom extends Component {
  static controlType = "custom";

  <template>
    <div class="form-kit__control-custom">
      {{yield}}
    </div>
  </template>
}
