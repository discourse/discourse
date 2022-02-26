import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("format-delay", function (minutes) {
  return minutes
    ? moment.duration(parseInt(minutes, 10), "minutes").humanize()
    : "-";
});
