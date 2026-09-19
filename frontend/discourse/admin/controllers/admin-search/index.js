import Controller from "@ember/controller";
import { service } from "@ember/service";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { i18n } from "discourse-i18n";

export default class AdminSearchIndexController extends Controller {
  @service capabilities;

  queryParams = ["filter"];

  /** The page description, mentioning the shortcut only where there is a keyboard to press it. */
  get description() {
    const description = i18n(
      "admin.config.search_everything.header_description"
    );

    if (!this.capabilities.hasKeyboard) {
      return description;
    }

    const shortcutHTML = formatShortcut("mod+/")
      .keys.map((key) => `<kbd>${key.label}</kbd>`)
      .join(" ");

    return `${description} ${i18n("admin.config.search_everything.header_shortcut", { shortcutHTML })}`;
  }
}
