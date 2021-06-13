import Component from "@ember/component";
import I18n from "I18n";
import UtilsMixin from "select-kit/mixins/utils";
import { computed } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { isPresent } from "@ember/utils";
import layout from "select-kit/templates/components/select-kit/select-kit-filter";
import { not } from "@ember/object/computed";

export default Component.extend(UtilsMixin, {
  layout,
  classNames: ["select-kit-filter"],
  classNameBindings: ["isExpanded:is-expanded"],
  attributeBindings: ["role"],
  tabIndex: -1,

  isHidden: computed(
    "selectKit.options.{filterable,allowAny,autoFilterable}",
    "content.[]",
    function () {
      return (
        !this.selectKit.options.filterable &&
        !this.selectKit.options.allowAny &&
        !this.selectKit.options.autoFilterable
      );
    }
  ),

  isExpanded: not("isHidden"),

  @discourseComputed(
    "selectKit.options.filterPlaceholder",
    "selectKit.options.translatedFilterPlaceholder"
  )
  placeholder(placeholder, translatedPlaceholder) {
    if (isPresent(translatedPlaceholder)) {
      return translatedPlaceholder;
    }

    if (isPresent(placeholder)) {
      return I18n.t(placeholder);
    }

    return "";
  },

  actions: {
    onPaste() {},

    onInput(event) {
      this.selectKit.onInput(event);
      return true;
    },

    onKeyup(event) {
      if (event.keyCode === 13 && this.selectKit.enterDisabled) {
        this.element.querySelector("input").focus();
        event.preventDefault();
        event.stopPropagation();
        return false;
      }
      return true;
    },

    onKeydown(event) {
      if (!this.selectKit.onKeydown(event)) {
        return false;
      }

      // Do nothing for left/right arrow
      if (event.keyCode === 37 || event.keyCode === 39) {
        return true;
      }

      // Up arrow
      if (event.keyCode === 38) {
        this.selectKit.highlightPrevious();
        return false;
      }

      // Down arrow
      if (event.keyCode === 40) {
        this.selectKit.highlightNext();
        return false;
      }

      // Escape
      if (event.keyCode === 27) {
        this.selectKit.mainElement().open = false;
        this.selectKit.headerElement().focus();
        return false;
      }

      // Enter
      if (event.keyCode === 13 && this.selectKit.highlighted) {
        this.selectKit.select(
          this.getValue(this.selectKit.highlighted),
          this.selectKit.highlighted
        );
        return false;
      }

      if (
        event.keyCode === 13 &&
        (!this.selectKit.highlighted || this.selectKit.enterDisabled)
      ) {
        this.element.querySelector("input").focus();
        if (this.selectKit.enterDisabled) {
          event.preventDefault();
          event.stopPropagation();
        }
        return false;
      }

      this.selectKit.set("highlighted", null);
    },
  },
});
