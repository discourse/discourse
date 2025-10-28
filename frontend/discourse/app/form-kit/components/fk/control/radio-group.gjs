import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FKFieldset from "discourse/form-kit/components/fk/fieldset";
import FKControlRadioGroupRadio from "./radio-group/radio";

export default class FKControlRadioGroup extends Component {
  static controlType = "radio-group";

  <template>
    <FKFieldset
      class="form-kit__control-radio-group"
      @title={{@title}}
      @subtitle={{@subtitle}}
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
