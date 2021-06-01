import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import { number } from "discourse/lib/formatter";

export default registerUnbound("directory-item-value", function (item, column) {
  return htmlSafe(
    `<span class='number'>${number(item.get(column.name))}</span>`
  );
});
