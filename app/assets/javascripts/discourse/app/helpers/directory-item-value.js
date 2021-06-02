import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import { number } from "discourse/lib/formatter";

export default registerUnbound("directory-item-value", function (args) {
  // Args should include key/values { item, column }

  return htmlSafe(
    `<span class='number'>${number(args.item.get(args.column.name))}</span>`
  );
});
