import I18n from "I18n";
import { computed } from "@ember/object";
import BaseField from "./da-base-field";

export default class ChoicesField extends BaseField {
  @computed("field.extra.content.[]")
  get replacedContent() {
    return (this.field.extra.content || []).map((r) => {
      return {
        id: r.id,
        name: I18n.t(r.name),
      };
    });
  }
}
