import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { isBlank } from "@ember/utils";
import DSelect, { DSelectOption } from "discourse/components/d-select";

const SelectOption = <template>
  <DSelectOption
    @value={{@value}}
    @selected={{@selected}}
    class="form-kit__control-option"
  >
    {{yield}}
  </DSelectOption>
</template>;

export default class FKControlSelect extends Component {
  static controlType = "select";

  get includeNone() {
    if (isBlank(this.args.field.value)) {
      return true;
    }

    return (
      this.args.includeNone ?? !this.args.field.validation?.includes("required")
    );
  }

  <template>
    <DSelect
      class="form-kit__control-select"
      disabled={{@field.disabled}}
      @value={{@field.value}}
      @onChange={{@field.set}}
      @includeNone={{this.includeNone}}
      ...attributes
    >
      {{yield (hash Option=(component SelectOption selected=@field.value))}}
    </DSelect>
  </template>
}
