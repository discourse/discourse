import Component from "@glimmer/component";
import BooleanField from "./types/boolean";
import CategoryField from "./types/category";
import EnumField from "./types/enum";
import FloatField from "./types/float";
import GroupField from "./types/group";
import IntegerField from "./types/integer";
import StringField from "./types/string";
import TagField from "./types/tag";

export default class SchemaThemeSettingField extends Component {
  get component() {
    switch (this.args.spec.type) {
      case "string":
        return StringField;
      case "integer":
        return IntegerField;
      case "float":
        return FloatField;
      case "boolean":
        return BooleanField;
      case "enum":
        return EnumField;
      case "category":
        return CategoryField;
      case "tag":
        return TagField;
      case "group":
        return GroupField;
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
