import Mixin from "@ember/object/mixin";
import { isEmpty } from "@ember/utils";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";

export default Mixin.create({
  validateCreate(filter, content) {
    if (!filter.length) {
      return;
    }

    const maximum = this.selectKit.options.maximum;
    if (maximum && makeArray(this.value).length >= parseInt(maximum, 10)) {
      this.addError(
        i18n("select_kit.max_content_reached", {
          count: parseInt(maximum, 10),
        })
      );
      return false;
    }

    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    filter = filter.replace(filterRegexp, "").trim().toLowerCase();

    if (this.termMatchesForbidden) {
      return false;
    }

    const toLowerCaseOrUndefined = (string) => {
      return isEmpty(string) ? undefined : string.toLowerCase();
    };

    const inCollection = content
      .map((c) => toLowerCaseOrUndefined(this.getValue(c)))
      .filter(Boolean)
      .includes(filter);

    const inSelection = (this.value || [])
      .map((s) => toLowerCaseOrUndefined(s))
      .filter(Boolean)
      .includes(filter);

    if (inCollection || inSelection) {
      return false;
    }

    return true;
  },
});
