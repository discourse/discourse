import { classNames } from "@ember-decorators/component";
import FilterForMore from "select-kit/components/filter-for-more";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  MAIN_COLLECTION,
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

const FILTER_FOR_MORE_GROUPS_COLLECTION = "MORE_GROUPS_COLLECTION";

@classNames("group-chooser")
@selectKitOptions({
  allowAny: false,
  displayedGroupsLimit: 100,
})
@pluginApiIdentifiers("group-chooser")
export default class GroupChooser extends MultiSelectComponent {
  init() {
    super.init(...arguments);

    this.insertAfterCollection(
      MAIN_COLLECTION,
      FILTER_FOR_MORE_GROUPS_COLLECTION
    );
  }

  modifyComponentForCollection(identifier) {
    if (identifier === FILTER_FOR_MORE_GROUPS_COLLECTION) {
      return FilterForMore;
    }
  }

  modifyContent(content) {
    const limit = this.selectKit.options.displayedGroupsLimit;
    if (content.length > limit) {
      this.showFilterForMore = true;
      content = content.slice(0, limit);
    } else {
      this.showFilterForMore = false;
    }
    return content;
  }

  modifyContentForCollection(identifier) {
    if (identifier === FILTER_FOR_MORE_GROUPS_COLLECTION) {
      return {
        shouldShowMoreTip: this.showFilterForMore,
      };
    }
  }
}
