import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default function shortcutLabel(...keys) {
  return keys
    .map((key) =>
      key === "meta"
        ? translateModKey("Meta")
        : i18n(`shortcut_modifier_key.${key}`)
    )
    .join(" + ");
}
