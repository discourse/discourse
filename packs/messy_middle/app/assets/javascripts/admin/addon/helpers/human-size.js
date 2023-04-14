import I18n from "I18n";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper((size) => I18n.toHumanSize(size));
