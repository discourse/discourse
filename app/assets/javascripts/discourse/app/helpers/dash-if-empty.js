import { isEmpty } from "@ember/utils";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(str => (isEmpty(str) ? "&mdash;" : str));
