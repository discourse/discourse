import Controller from "@ember/controller";
import { formatShortcut } from "discourse/lib/shortcut-format";

export default class AdminSearchIndexController extends Controller {
  queryParams = ["filter"];

  get shortcutHTML() {
    return formatShortcut("mod+/")
      .keys.map((key) => `<kbd>${key.label}</kbd>`)
      .join(" ");
  }
}
