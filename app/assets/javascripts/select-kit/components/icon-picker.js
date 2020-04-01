import MultiSelectComponent from "select-kit/components/multi-select";
import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { makeArray } from "discourse-common/lib/helpers";
import { convertIconClass } from "discourse-common/lib/icon-library";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["icon-picker"],
  classNames: ["icon-picker"],

  init() {
    this._super(...arguments);

    this._cachedIconsList = null;

    if (Discourse.Environment === "development") {
      Discourse.disableMissingIconWarning = true;
    }
  },

  content: computed("value.[]", function() {
    return makeArray(this.value).map(this._processIcon);
  }),

  search(filter = "") {
    if (
      filter === "" &&
      this._cachedIconsList &&
      this._cachedIconsList.length
    ) {
      return this._cachedIconsList;
    } else {
      return ajax("/svg-sprite/picker-search", {
        data: { filter }
      }).then(icons => {
        icons = icons.map(this._processIcon);
        if (filter === "") {
          this._cachedIconsList = icons;
        }
        return icons;
      });
    }
  },

  _processIcon(icon) {
    const iconName = typeof icon === "object" ? icon.id : icon,
      strippedIconName = convertIconClass(iconName);

    const spriteEl = "#svg-sprites",
      holder = "ajax-icon-holder";

    if (typeof icon === "object") {
      if ($(`${spriteEl} .${holder}`).length === 0)
        $(spriteEl).append(
          `<div class="${holder}" style='display: none;'></div>`
        );

      if (!$(`${spriteEl} symbol#${strippedIconName}`).length) {
        $(`${spriteEl} .${holder}`).append(
          `<svg xmlns='http://www.w3.org/2000/svg'>${icon.symbol}</svg>`
        );
      }
    }

    return {
      id: iconName,
      name: iconName,
      icon: strippedIconName
    };
  },

  willDestroyElement() {
    $("#svg-sprites .ajax-icon-holder").remove();
    this._super(...arguments);

    this._cachedIconsList = null;

    if (Discourse.Environment === "development") {
      delete Discourse.disableMissingIconWarning;
    }
  },

  actions: {
    onChange(value, item) {
      if (this.selectKit.options.maximum === 1) {
        value = value.length ? value[0] : null;
        item = item.length ? item[0] : null;
      }

      this.attrs.onChange && this.attrs.onChange(value, item);
    }
  }
});
