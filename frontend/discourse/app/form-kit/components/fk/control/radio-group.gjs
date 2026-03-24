import { hash } from "@ember/helper";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import FKFieldset from "discourse/form-kit/components/fk/fieldset";
import FKControlRadioGroupRadio from "./radio-group/radio";

export default class FKControlRadioGroup extends FKBaseControl {
  static controlType = "radio-group";

  <template>
    <FKFieldset
      class="form-kit__control-radio-group"
      @title={{@title}}
      @description={{@description}}
      id={{@field.id}}
      name={{@field.name}}
      aria-invalid={{if @field.error "true"}}
      aria-describedby={{if @field.error @field.errorId}}
      ...attributes
    >
      {{yield
        (hash
          Radio=(component FKControlRadioGroupRadio value=@value field=@field)
        )
      }}
    </FKFieldset>
  </template>
}
