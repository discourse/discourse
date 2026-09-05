import { hash } from "@ember/helper";
import { isBlank } from "@ember/utils";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import DNativeSelect, {
  DNativeSelectOption,
} from "discourse/ui-kit/d-native-select";

const SelectOption = <template>
  <DNativeSelectOption
    @value={{@value}}
    @selected={{@selected}}
    class="form-kit__control-option"
  >
    {{yield}}
  </DNativeSelectOption>
</template>;

export default class FKControlSelect extends FKBaseControl {
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
    <DNativeSelect
      class="form-kit__control-select"
      disabled={{@field.disabled}}
      @value={{@field.value}}
      @onChange={{@field.set}}
      @includeNone={{this.includeNone}}
      @nonePlaceholder={{@nonePlaceholder}}
      id={{@field.id}}
      name={{@field.name}}
      aria-invalid={{if @field.error "true"}}
      aria-describedby={{@field.describedBy}}
      ...attributes
    >
      {{yield (hash Option=(component SelectOption selected=@field.value))}}
    </DNativeSelect>
  </template>
}
