import { not } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

const { isEmpty } = Ember;

export default Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-filter",
  classNames: ["select-kit-filter"],
  classNameBindings: ["isFocused", "isHidden"],
  isHidden: not("shouldDisplayFilter"),

  @discourseComputed("placeholder")
  computedPlaceholder(placeholder) {
    return isEmpty(placeholder) ? "" : I18n.t(placeholder);
  }
});
