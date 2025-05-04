import Controller from "@ember/controller";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";

export default class AdminSearchIndexController extends Controller {
  queryParams = ["filter"];

  get shortcutHTML() {
    return `<kbd>${translateModKey(PLATFORM_KEY_MODIFIER)}</kbd> + <kbd>/</kbd>`;
  }
}
