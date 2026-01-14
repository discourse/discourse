import Controller from "@ember/controller";
import { translateModKey } from "discourse/lib/utilities";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";

export default class AdminSearchIndexController extends Controller {
  queryParams = ["filter"];

  get shortcutHTML() {
    return `<kbd>${translateModKey(PLATFORM_KEY_MODIFIER)}</kbd> <kbd>/</kbd>`;
  }
}
