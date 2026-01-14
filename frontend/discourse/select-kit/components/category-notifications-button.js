import { readOnly } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import NotificationOptionsComponent from "discourse/select-kit/components/notifications-button";
import { i18n } from "discourse-i18n";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@selectKitOptions({
  i18nPrefix: "category.notifications",
  showFullTitle: false,
  headerAriaLabel: i18n("category.notifications.title"),
})
@pluginApiIdentifiers(["category-notifications-button"])
@classNames("category-notifications-button")
export default class CategoryNotificationsButton extends NotificationOptionsComponent {
  @readOnly("category.deleted") isHidden;
}
