import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import $ from "jquery";
import { ajax } from "discourse/lib/ajax";
import { makeArray } from "discourse/lib/helpers";
import {
  convertIconClass,
  disableMissingIconWarning,
  enableMissingIconWarning,
} from "discourse/lib/icon-library";
import { isDevelopment } from "discourse-common/config/environment";
import FilterForMore from "select-kit/components/filter-for-more";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  MAIN_COLLECTION,
  pluginApiIdentifiers,
} from "select-kit/components/select-kit";

const MORE_ICONS_COLLECTION = "MORE_ICONS_COLLECTION";
const MAX_RESULTS_RETURNED = 200;
// Matches  max returned results from icon_picker_search in svg_sprite_controller.rb

@classNames("icon-picker")
@pluginApiIdentifiers("icon-picker")
export default class IconPicker extends MultiSelectComponent {
  init() {
    super.init(...arguments);

    this._cachedIconsList = null;
    this._resultCount = 0;

    if (isDevelopment()) {
      disableMissingIconWarning();
    }

    this.insertAfterCollection(MAIN_COLLECTION, MORE_ICONS_COLLECTION);
  }

  modifyComponentForCollection(collection) {
    if (collection === MORE_ICONS_COLLECTION) {
      return FilterForMore;
    }
  }

  modifyContentForCollection(collection) {
    if (collection === MORE_ICONS_COLLECTION) {
      return {
        shouldShowMoreTip: this._resultCount === MAX_RESULTS_RETURNED,
      };
    }
  }

  @computed("value.[]")
  get content() {
    return makeArray(this.value).map(this._processIcon);
  }

  search(filter = "") {
    if (filter === "" && this._cachedIconsList?.length) {
      this._resultCount = this._cachedIconsList.length;
      return this._cachedIconsList;
    } else {
      return ajax("/svg-sprite/picker-search", {
        data: {
          filter,
          only_available: this.onlyAvailable,
        },
      }).then((icons) => {
        icons = icons.map(this._processIcon);
        if (filter === "") {
          this._cachedIconsList = icons;
        }
        this._resultCount = icons.length;
        return icons;
      });
    }
  }

  _processIcon(icon) {
    const iconName = typeof icon === "object" ? icon.id : icon,
      strippedIconName = convertIconClass(iconName);

    const spriteEl = "#svg-sprites",
      holder = "ajax-icon-holder";

    if (typeof icon === "object") {
      if ($(`${spriteEl} .${holder}`).length === 0) {
        $(spriteEl).append(
          `<div class="${holder}" style='display: none;'></div>`
        );
      }

      if (!$(`${spriteEl} symbol#${strippedIconName}`).length) {
        $(`${spriteEl} .${holder}`).append(
          `<svg xmlns='http://www.w3.org/2000/svg'>${icon.symbol}</svg>`
        );
      }
    }

    return {
      id: iconName,
      name: iconName,
      icon: strippedIconName,
    };
  }

  willDestroyElement() {
    $("#svg-sprites .ajax-icon-holder").remove();
    super.willDestroyElement(...arguments);

    this._cachedIconsList = null;
    this._resultCount = 0;

    if (isDevelopment()) {
      enableMissingIconWarning();
    }
  }

  @action
  _onChange(value, item) {
    if (this.selectKit.options.maximum === 1) {
      value = value.length ? value[0] : null;
      item = item.length ? item[0] : null;
    }

    this.onChange?.(value, item);
  }
}
