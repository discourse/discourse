import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import deprecated from "discourse/lib/deprecated";
import { makeArray } from "discourse/lib/helpers";
import {
  convertIconClass,
  suppressMissingIconWarnings,
} from "discourse/lib/icon-library";
import { addExtraSpriteSymbols } from "discourse/lib/svg-sprite-loader";
import FilterForMore from "discourse/select-kit/components/filter-for-more";
import MultiSelectComponent from "discourse/select-kit/components/multi-select";
import {
  MAIN_COLLECTION,
  pluginApiIdentifiers,
} from "discourse/select-kit/components/select-kit";

const MORE_ICONS_COLLECTION = "MORE_ICONS_COLLECTION";

@classNames("icon-picker")
@pluginApiIdentifiers("icon-picker")
export default class IconPicker extends MultiSelectComponent {
  init() {
    super.init(...arguments);

    deprecated(
      "IconPicker (SelectKit) is deprecated. Use `DIconGridPicker` instead.",
      { id: "discourse.icon-picker", since: "2026.3" }
    );

    this._cachedIconsList = null;
    this._cachedHasMore = false;
    this._hasMore = false;

    suppressMissingIconWarnings(this);

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
        shouldShowMoreTip: this._hasMore,
      };
    }
  }

  @computed("value.[]")
  get content() {
    return makeArray(this.value).map(this._processIcon);
  }

  search(filter = "") {
    if (filter === "" && this._cachedIconsList?.length) {
      this._hasMore = this._cachedHasMore;
      return this._cachedIconsList;
    } else {
      return ajax("/svg-sprite/picker-search", {
        data: {
          filter,
          only_available: this.onlyAvailable,
        },
      }).then((response) => {
        addExtraSpriteSymbols(response.icons);
        const icons = response.icons.map(this._processIcon);
        if (filter === "") {
          this._cachedIconsList = icons;
          this._cachedHasMore = response.has_more;
        }
        this._hasMore = response.has_more;
        return icons;
      });
    }
  }

  _processIcon(icon) {
    const iconName = typeof icon === "object" ? icon.id : icon,
      strippedIconName = convertIconClass(iconName);

    return {
      id: iconName,
      name: iconName,
      icon: strippedIconName,
    };
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this._cachedIconsList = null;
    this._cachedHasMore = false;
    this._hasMore = false;
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
