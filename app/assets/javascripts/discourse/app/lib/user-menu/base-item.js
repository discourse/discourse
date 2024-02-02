import UserMenuIconAvatar from "discourse/components/user-menu/icon-avatar";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DiscourseURL from "discourse/lib/url";

export default class UserMenuBaseItem {
  constructor({ siteSettings, site }) {
    this.site = site;
    this.siteSettings = siteSettings;
  }
  get className() {}

  get linkHref() {
    throw new Error("not implemented");
  }

  get linkTitle() {
    throw new Error("not implemented");
  }

  get icon() {
    throw new Error("not implemented");
  }

  get label() {
    throw new Error("not implemented");
  }

  get labelClass() {}

  get description() {
    throw new Error("not implemented");
  }

  get descriptionClass() {}

  get topicId() {}

  get avatarTemplate() {}

  get iconComponent() {
    return this.siteSettings.show_user_menu_avatars ? UserMenuIconAvatar : null;
  }

  get iconComponentArgs() {
    return {
      avatarTemplate:
        this.avatarTemplate || this.site.system_user_avatar_template,
      icon: this.icon,
      classNames: this.avatarTemplate ? "user-avatar" : "system-avatar",
    };
  }

  onClick({ event, closeUserMenu }) {
    if (wantsNewWindow(event)) {
      return;
    }
    closeUserMenu();
    const href = this.linkHref;
    if (href) {
      DiscourseURL.routeTo(href);
    }
    event.preventDefault();
  }
}
