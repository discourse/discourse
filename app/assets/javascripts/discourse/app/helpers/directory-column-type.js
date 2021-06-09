import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";
import I18n from "I18n";

export default registerUnbound("directory-column-is-automatic", function (args) {
  // Args should include key/values { column }

  console.log(args.column)
  return args.column.type === 0;
});
