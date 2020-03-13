import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("value-at-tl", function(data, params) {
  var tl = parseInt(params.level, 10);
  if (data) {
    var item = data.find(function(d) {
      return parseInt(d.x, 10) === tl;
    });
    if (item) {
      return item.y;
    } else {
      return 0;
    }
  }
});
