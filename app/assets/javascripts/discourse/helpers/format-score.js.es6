import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("format-score", function(score) {
  return I18n.toNumber(score || 0, { precision: 1 });
});
