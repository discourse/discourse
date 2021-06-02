import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";

export default registerUnbound("directory-item-label", function (item, column) {
  const count = item.get(column.name);

  return htmlSafe(I18n.t(`directory.${column.name}`, { count }));
});
