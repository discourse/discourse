import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { computed } from "@ember/object";
import { not } from "@ember/object/computed";
import UtilsMixin from "select-kit/mixins/utils";

export default Component.extend(UtilsMixin, {
  layoutName: "select-kit/templates/components/select-kit/select-kit-filter",
  classNames: ["select-kit-filter"],
  classNameBindings: ["isExpanded:is-expanded"],
  attributeBindings: ["selectKitId:data-select-kit-id"],
  selectKitId: computed("selectKit.uniqueID", function() {
    return `${this.selectKit.uniqueID}-filter`;
  }),

  isHidden: computed(
    "selectKit.options.{filterable,allowAny,autoFilterable}",
    "content.[]",
    function() {
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
    "selectKit.options.translatedfilterPlaceholder"
  )
  placeholder(placeholder, translatedPlaceholder) {
    return isEmpty(placeholder)
      ? translatedPlaceholder
        ? translatedPlaceholder
        : ""
      : I18n.t(placeholder);
  },

  actions: {
    onInput(event) {
      this.selectKit.onInput(event);
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
        this.selectKit.close(event);
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

      if (event.keyCode === 13 && !this.selectKit.highlighted) {
        this.element.querySelector("input").focus();
        return false;
      }

      // Tab
      if (event.keyCode === 9) {
        if (this.selectKit.highlighted && this.selectKit.isExpanded) {
          this.selectKit.select(
            this.getValue(this.selectKit.highlighted),
            this.selectKit.highlighted
          );
        }
        this.selectKit.close(event);
        return;
      }
    }
  }
});
