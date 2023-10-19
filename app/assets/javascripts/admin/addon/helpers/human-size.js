import { htmlHelper } from "discourse-common/lib/helpers";
import I18n from "discourse-i18n";

export default htmlHelper((size) => I18n.toHumanSize(size));
