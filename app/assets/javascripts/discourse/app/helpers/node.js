import { h } from "virtual-dom";
import { relativeAge, longDate } from "discourse/lib/formatter";
import { number } from "discourse/lib/formatter";

export function dateNode(dt) {
  if (typeof dt === "string") {
    dt = new Date(dt);
  }
  if (dt) {
    const attributes = {
      title: longDate(dt),
      "data-time": dt.getTime(),
      "data-format": "tiny"
    };

    return h("span.relative-date", { attributes }, relativeAge(dt));
  }
}

export function numberNode(num, opts) {
  opts = opts || {};
  num = parseInt(num, 10);
  if (isNaN(num)) {
    num = 0;
  }

  const numString = num.toString();
  const attributes = {};
  const formatted = number(num);
  if (formatted !== numString) {
    attributes.title = numString;
  }

  return h("span.number", { className: opts.className, attributes }, formatted);
}
