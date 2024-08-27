import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("topic-footer-mobile-dropdown")
@selectKitOptions({
  none: "topic.controls",
  filterable: false,
  autoFilterable: false,
})
@pluginApiIdentifiers("topic-footer-mobile-dropdown")
export default class TopicFooterMobileDropdown extends ComboBoxComponent {
  @action
  onChange(value, item) {
    item.action && item.action();
  }
}
