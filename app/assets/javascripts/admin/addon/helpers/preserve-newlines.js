import { escapeExpression } from "discourse/lib/utilities";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper((str) =>
  escapeExpression(str).replace(/\n/g, "<br>")
);
