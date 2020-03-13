import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(dt =>
  autoUpdatingRelativeAge(new Date(dt), { format: "medium", title: true })
);
