import I18n from "I18n";
import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  tagName: "",

  replacedContent: computed("field.extra.content.[]", function() {
    return (this.field.extra.content || []).map(r => {
      return {
        id: r.id,
        name: I18n.t(r.name)
      };
    });
  })
});
