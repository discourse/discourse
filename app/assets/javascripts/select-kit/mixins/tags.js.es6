import { reads } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Mixin from "@ember/object/mixin";
import { makeArray } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

export default Mixin.create({
  searchTags(url, data, callback) {
    return ajax(Discourse.getURL(url), {
      quietMillis: 200,
      cache: true,
      dataType: "json",
      data
    })
      .then(json => callback(this, json))
      .catch(popupAjaxError);
  },

  selectKitOptions: {
    allowAny: "allowAnyTag"
  },

  allowAnyTag: reads("site.can_create_tag"),

  validateCreate(filter, content) {
    const maximum = this.selectKit.options.maximum;
    if (maximum && makeArray(this.value).length >= parseInt(maximum, 10)) {
      this.addError(
        I18n.t("select_kit.max_content_reached", {
          count: this.selectKit.limit
        })
      );
      return false;
    }

    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    filter = filter
      .replace(filterRegexp, "")
      .trim()
      .toLowerCase();

    if (this.termMatchesForbidden) {
      return false;
    }

    if (
      !filter.length ||
      this.get("siteSettings.max_tag_length") < filter.length
    ) {
      this.addError(
        I18n.t("select_kit.invalid_selection_length", {
          count: `[1 - ${this.get("siteSettings.max_tag_length")}]`
        })
      );
      return false;
    }

    const toLowerCaseOrUndefined = string => {
      return isEmpty(string) ? undefined : string.toLowerCase();
    };

    const inCollection = content
      .map(c => toLowerCaseOrUndefined(this.getValue(c)))
      .filter(Boolean)
      .includes(filter);

    const inSelection = (this.value || [])
      .map(s => toLowerCaseOrUndefined(s))
      .filter(Boolean)
      .includes(filter);

    if (inCollection || inSelection) {
      return false;
    }

    return true;
  },

  createContentFromInput(input) {
    // See lib/discourse_tagging#clean_tag.
    input = input
      .trim()
      .replace(/\s+/g, "-")
      .replace(/[\/\?#\[\]@!\$&'\(\)\*\+,;=\.%\\`^\s|\{\}"<>]+/g, "")
      .substring(0, this.siteSettings.max_tag_length);

    if (this.siteSettings.force_lowercase_tags) {
      input = input.toLowerCase();
    }

    return input;
  }
});
