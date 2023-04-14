import I18n from "I18n";
import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper((key, params) => I18n.t(key, params.hash));
