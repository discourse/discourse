import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { fmt } from "discourse/lib/computed";
import DropdownSelectBoxHeaderComponent from "discourse/select-kit/components/dropdown-select-box/dropdown-select-box-header";
import { i18n } from "discourse-i18n";

@classNames("notifications-filter-header", "btn-flat")
export default class NotificationsFilterHeader extends DropdownSelectBoxHeaderComponent {
  @fmt("value", "user.user_notifications.filters.%@") label;

  @computed("selectKit.isExpanded")
  get caretIcon() {
    return this.selectKit?.isExpanded ? "caret-up" : "caret-down";
  }

  <template>
    <div class="select-kit-header-wrapper">
      <span class="filter-text">
        {{i18n "user.user_notifications.filters.filter_by"}}
      </span>
      <span class="header-text">
        {{i18n this.label}}
      </span>
      {{icon this.caretIcon class="caret-icon"}}
    </div>
  </template>
}
