/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import { trustHTML } from "@ember/template";
import { number as numberFormatter } from "discourse/lib/formatter";
import { escapeExpression } from "discourse/lib/utilities";
import I18n, { i18n } from "discourse-i18n";

/**
 * Renders a number in a span, shortened by the number formatter, with the full
 * number as its title.
 *
 * @param orig - The number. Values that do not parse as a number count as 0.
 * @param params - The options.
 * @returns The span.
 */
export default function dNumber(
  orig: number | string | null | undefined,
  params: {
    /** A translation key for the title, given the number and its count. */
    numberKey?: string;

    /** Classes added after `number`. */
    class?: string;

    /** Leaves out the title. */
    noTitle?: boolean;

    /** The largest number shown, with a `+` after it. */
    maxDisplay?: number;

    /** The aria label. */
    ariaLabel?: string;
  } = {}
) {
  // `parseFloat` converts any value to a string first.
  orig = Math.round(parseFloat(orig as string));
  if (isNaN(orig)) {
    orig = 0;
  }

  let title = I18n.toNumber(orig, { precision: 0 });
  if (params.numberKey) {
    title = i18n(params.numberKey, {
      number: title,
      // `parseInt` converts any value to a string first.
      count: parseInt(orig as unknown as string, 10),
    });
  }

  let classNames = "number";
  if (params["class"]) {
    classNames += " " + params["class"];
  }

  let result = "<span class='" + classNames + "'";
  let addTitle = params.noTitle ? false : true;

  // Round off the thousands to one decimal place
  const n = numberFormatter(orig, { maxDisplay: params.maxDisplay });
  if (n.toString() !== title.toString() && addTitle) {
    result += " title='" + escapeExpression(title) + "'";
  }
  if (params.ariaLabel) {
    const ariaLabel = escapeExpression(params.ariaLabel);
    result += ` aria-label='${ariaLabel}'`;
  }

  result += ">" + n + "</span>";

  return trustHTML(result);
}
