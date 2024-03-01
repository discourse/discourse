import Component from "@glimmer/component";
import BooleanField from "./types/boolean";
import EnumField from "./types/enum";
import IntegerField from "./types/integer";
import StringField from "./types/string";

export default class SchemaThemeSettingField extends Component {
  get component() {
    switch (this.args.spec.type) {
      case "string":
        return StringField;
      case "integer":
        return IntegerField;
      case "boolean":
        return BooleanField;
      case "enum":
        return EnumField;
      default:
        throw new Error("unknown type");
    }
  }

  <template>
    <div class="schema-field" data-name={{@name}}>
      <label>{{@name}}</label>
      <div class="input">
        <this.component
          @value={{@value}}
          @spec={{@spec}}
          @onChange={{@onValueChange}}
        />
      </div>
    </div>
  </template>
}
