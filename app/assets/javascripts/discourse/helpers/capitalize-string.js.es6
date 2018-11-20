import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(str => str[0].toUpperCase() + str.slice(1));
