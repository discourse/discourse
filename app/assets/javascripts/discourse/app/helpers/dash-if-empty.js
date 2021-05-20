import { htmlHelper } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

export default htmlHelper((str) => (isEmpty(str) ? "&mdash;" : str));
