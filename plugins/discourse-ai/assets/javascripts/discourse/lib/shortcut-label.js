import { formatShortcut } from "discourse/lib/shortcut-format";
import { i18n } from "discourse-i18n";

export default function shortcutLabel(...keys) {
  return keys
    .map((key) =>
      key === "meta"
        ? formatShortcut("mod").label
        : i18n(`shortcut_modifier_key.${key}`)
    )
    .join(" + ");
}
