import { registerUnbound } from "discourse-common/lib/helpers";
import {
  longDate,
  autoUpdatingRelativeAge,
  number
} from "discourse/lib/formatter";

const safe = Handlebars.SafeString;

registerUnbound("raw-date", dt => longDate(new Date(dt)));

registerUnbound(
  "age-with-tooltip",
  dt => new safe(autoUpdatingRelativeAge(new Date(dt), { title: true }))
);

registerUnbound("number", (orig, params) => {
  orig = Math.round(parseFloat(orig));
  if (isNaN(orig)) {
    orig = 0;
  }

  let title = I18n.toNumber(orig, { precision: 0 });
  if (params.numberKey) {
    title = I18n.t(params.numberKey, {
      number: title,
      count: parseInt(orig, 10)
    });
  }

  let classNames = "number";
  if (params["class"]) {
    classNames += " " + params["class"];
  }

  let result = "<span class='" + classNames + "'";
  let addTitle = params.noTitle ? false : true;

  // Round off the thousands to one decimal place
  const n = number(orig);
  if (n.toString() !== title.toString() && addTitle) {
    result += " title='" + Handlebars.Utils.escapeExpression(title) + "'";
  }
  result += ">" + n + "</span>";

  return new safe(result);
});
