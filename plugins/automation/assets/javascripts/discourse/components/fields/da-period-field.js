import I18n from "I18n";
import { computed } from "@ember/object";
import BaseField from "./da-base-field";

export default class IntervalField extends BaseField {
  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (!this.field.metadata.value) {
      this.set("field.metadata.value", {
        interval: 1,
        frequency: null,
      });
    }
  }

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
