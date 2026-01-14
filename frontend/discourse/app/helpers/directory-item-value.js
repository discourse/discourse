import { htmlSafe } from "@ember/template";
import { number } from "discourse/lib/formatter";

export default function directoryItemValue(args) {
  // Args should include key/values { item, column }
  return htmlSafe(
    `<span class='directory-table__value'>${number(
      args.item.get(args.column.name)
    )}</span>`
  );
}
