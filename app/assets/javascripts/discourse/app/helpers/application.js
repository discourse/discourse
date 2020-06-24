import I18n from "I18n";
import { registerUnbound } from "discourse-common/lib/helpers";
import {
  longDate,
  autoUpdatingRelativeAge,
  number
} from "discourse/lib/formatter";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

registerUnbound("raw-date", dt => htmlSafe(longDate(new Date(dt))));

registerUnbound("age-with-tooltip", dt =>
  htmlSafe(autoUpdatingRelativeAge(new Date(dt), { title: true }))
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
    result += " title='" + escapeExpression(title) + "'";
  }
  if (params.ariaLabel) {
    const ariaLabel = escapeExpression(params.ariaLabel);
    result += ` aria-label='${ariaLabel}'`;
  }

  result += ">" + n + "</span>";

  return htmlSafe(result);
});
