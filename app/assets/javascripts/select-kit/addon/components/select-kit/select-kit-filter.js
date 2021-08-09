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

  role: "searchbox",

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
      if (event.key === "Enter" && this.selectKit.enterDisabled) {
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
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        return true;
      }

      if (event.key === "ArrowUp") {
        this.selectKit.highlightPrevious();
        return false;
      }

      if (event.key === "ArrowDown") {
        this.selectKit.highlightNext();
        return false;
      }

      // Escape
      if (event.key === "Escape") {
        this.selectKit.close(event);
        return false;
      }

      // Enter
      if (event.key === "Enter" && this.selectKit.highlighted) {
        this.selectKit.select(
          this.getValue(this.selectKit.highlighted),
          this.selectKit.highlighted
        );
        return false;
      }

      if (
        event.key === "Enter" &&
        (!this.selectKit.highlighted || this.selectKit.enterDisabled)
      ) {
        this.element.querySelector("input").focus();
        if (this.selectKit.enterDisabled) {
          event.preventDefault();
          event.stopPropagation();
        }
        return false;
      }

      // Tab
      if (event.key === "Tab") {
        if (this.selectKit.highlighted && this.selectKit.isExpanded) {
          this.selectKit.select(
            this.getValue(this.selectKit.highlighted),
            this.selectKit.highlighted
          );
        }
        this.selectKit.close(event);
        return;
      }

      this.selectKit.set("highlighted", null);
    },
  },
});
