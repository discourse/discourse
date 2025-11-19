export {
  disableDefaultKeyboardShortcuts,
  clearDisabledDefaultKeyboardBindings,
  clearExtraKeyboardShortcutHelp,
  extraKeyboardShortcutsHelp,
  PLATFORM_KEY_MODIFIER,
} from "discourse/services/keyboard-shortcuts";
import { getOwnerWithFallback } from "./get-owner";

export default new Proxy(
  {},
  {
    get(_, prop, receiver) {
      const target = getOwnerWithFallback().lookup(
        "service:keyboard-shortcuts"
      );
      const result = Reflect.get(target, prop, receiver);
      return typeof result === "function" ? result.bind(target) : result;
    },
  }
);
