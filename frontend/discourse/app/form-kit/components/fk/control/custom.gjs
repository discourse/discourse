import FKBaseControl from "discourse/form-kit/components/fk/control/base";

export default class FKControlCustom extends FKBaseControl {
  static controlType = "custom";

  <template>
    <div class="form-kit__control-custom">
      {{yield}}
    </div>
  </template>
}
