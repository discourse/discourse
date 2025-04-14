import { classNames } from "@ember-decorators/component";
import { fmt } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";

@classNames("notifications-filter-header", "btn-flat")
export default class NotificationsFilterHeader extends DropdownSelectBoxHeaderComponent {
  @fmt("value", "user.user_notifications.filters.%@") label;

  @discourseComputed("selectKit.isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  }
}

<div class="select-kit-header-wrapper">
  <span class="filter-text">
    {{i18n "user.user_notifications.filters.filter_by"}}
  </span>
  <span class="header-text">
    {{i18n this.label}}
  </span>
  {{d-icon this.caretIcon class="caret-icon"}}
</div>