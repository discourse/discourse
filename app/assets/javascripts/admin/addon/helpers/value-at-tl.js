import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("value-at-tl", valueAtTl);

export default function valueAtTl(data, params = {}) {
  let tl = parseInt(params.level, 10);
  if (data) {
    let item = data.find(function (d) {
      return parseInt(d.x, 10) === tl;
    });
    if (item) {
      return item.y;
    } else {
      return 0;
    }
  }
}
