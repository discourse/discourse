import { htmlHelper } from "discourse-common/lib/helpers";
import I18n from "I18n";

export default htmlHelper((size) => I18n.toHumanSize(size));
