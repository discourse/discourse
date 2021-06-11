import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";

export default registerUnbound("mobile-directory-item-label", function (args) {
  // Args should include key/values { item, column }

  const count = args.item.get(args.column.name);
  return htmlSafe(I18n.t(`directory.${args.column.name}`, { count }));
});
