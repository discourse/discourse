import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import BooleanField from "admin/components/schema-setting/types/boolean";
import CategoriesField from "admin/components/schema-setting/types/categories";
import EnumField from "admin/components/schema-setting/types/enum";
import FloatField from "admin/components/schema-setting/types/float";
import GroupsField from "admin/components/schema-setting/types/groups";
import IntegerField from "admin/components/schema-setting/types/integer";
import StringField from "admin/components/schema-setting/types/string";
import TagsField from "admin/components/schema-setting/types/tags";

export default class SchemaSettingField extends Component {
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
      case "categories":
        return CategoriesField;
      case "tags":
        return TagsField;
      case "groups":
        return GroupsField;
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
    <div class="schema-field" data-name={{@name}} data-type={{@spec.type}}>
      <label class="schema-field__label">{{@label}}{{if
          @spec.required
          "*"
        }}</label>

      <div class="schema-field__input">
        <this.component
          @value={{@value}}
          @spec={{@spec}}
          @onChange={{@onValueChange}}
          @description={{this.description}}
          @setting={{@setting}}
        />
      </div>
    </div>
  </template>
}
