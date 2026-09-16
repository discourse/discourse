import { hash } from "@ember/helper";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import FKFieldset from "discourse/form-kit/components/fk/fieldset";
import FKControlRadioGroupRadio from "./radio-group/radio";

export default class FKControlRadioGroup extends FKBaseControl {
  static controlType = "radio-group";

  <template>
    <FKFieldset
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      class="form-kit__control-radio-group"
      id={{@field.id}}
      name={{@field.name}}
      ...attributes
      @description={{@description}}
      @title={{@title}}
    >
      {{yield
        (hash
          Radio=(component FKControlRadioGroupRadio value=@value field=@field)
        )
      }}
    </FKFieldset>
  </template>
}
