import { htmlSafe } from "@ember/template";
import { number as numberFormatter } from "discourse/lib/formatter";
import { registerRawHelper } from "discourse/lib/helpers";
import { escapeExpression } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

registerRawHelper("number", number);

export default function number(orig, params = {}) {
  orig = Math.round(parseFloat(orig));
  if (isNaN(orig)) {
    orig = 0;
  }

  let title = I18n.toNumber(orig, { precision: 0 });
  if (params.numberKey) {
    title = i18n(params.numberKey, {
      number: title,
      count: parseInt(orig, 10),
    });
  }

  let classNames = "number";
  if (params["class"]) {
    classNames += " " + params["class"];
  }

  let result = "<span class='" + classNames + "'";
  let addTitle = params.noTitle ? false : true;

  // Round off the thousands to one decimal place
  const n = numberFormatter(orig);
  if (n.toString() !== title.toString() && addTitle) {
    result += " title='" + escapeExpression(title) + "'";
  }
  if (params.ariaLabel) {
    const ariaLabel = escapeExpression(params.ariaLabel);
    result += ` aria-label='${ariaLabel}'`;
  }

  result += ">" + n + "</span>";

  return htmlSafe(result);
}
