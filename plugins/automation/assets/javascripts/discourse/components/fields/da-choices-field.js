import I18n from "I18n";
import { computed } from "@ember/object";
import BaseField from "./da-base-field";

export default BaseField.extend({
  replacedContent: computed("field.extra.content.[]", function () {
    return (this.field.extra.content || []).map((r) => {
      return {
        id: r.id,
        name: I18n.t(r.name),
      };
    });
  }),
});
