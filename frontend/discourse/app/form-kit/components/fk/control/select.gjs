import { hash } from "@ember/helper";
import { isBlank } from "@ember/utils";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import DNativeSelect, {
  DNativeSelectOption,
} from "discourse/ui-kit/d-native-select";

const SelectOption = <template>
  <DNativeSelectOption
    class="form-kit__control-option"
    @selected={{@selected}}
    @value={{@value}}
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
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      class="form-kit__control-select"
      disabled={{@field.disabled}}
      id={{@field.id}}
      name={{@field.name}}
      ...attributes
      @includeNone={{this.includeNone}}
      @nonePlaceholder={{@nonePlaceholder}}
      @onChange={{@field.set}}
      @value={{@field.value}}
    >
      {{yield (hash Option=(component SelectOption selected=@field.value))}}
    </DNativeSelect>
  </template>
}
