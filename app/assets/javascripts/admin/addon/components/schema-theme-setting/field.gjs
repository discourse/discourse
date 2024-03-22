import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import htmlSafe from "discourse-common/helpers/html-safe";
import BooleanField from "./types/boolean";
import CategoryField from "./types/category";
import EnumField from "./types/enum";
import FloatField from "./types/float";
import GroupField from "./types/group";
import IntegerField from "./types/integer";
import StringField from "./types/string";
import TagsField from "./types/tags";

export default class SchemaThemeSettingField extends Component {
  get component() {
    const type = this.args.spec.type;

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
      case "tags":
        return TagsField;
      case "group":
        return GroupField;
      default:
        throw new Error(`unknown type ${type}`);
    }
  }

  @cached
  get description() {
    if (!this.args.description) {
      return;
    }

    return htmlSafe(this.args.description.trim().replace(/\n/g, "<br>"));
  }

  <template>
    <div class="schema-field" data-name={{@name}}>
      <label class="schema-field__label">{{@name}}{{if
          @spec.required
          "*"
        }}</label>

      <div class="schema-field__input">
        <this.component
          @value={{@value}}
          @spec={{@spec}}
          @onChange={{@onValueChange}}
          @description={{this.description}}
        />
      </div>
    </div>
  </template>
}
