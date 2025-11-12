import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";

export default class TagUtils extends Service {
  @service siteSettings;
  @service site;

  searchTags(url, data, callback) {
    return ajax(url, { data })
      .then((json) => callback(json))
      .catch(popupAjaxError);
  }

  validateCreate(
    filter,
    content,
    maximum,
    addError,
    termMatchesForbidden,
    getValue,
    value
  ) {
    if (!filter.length) {
      return;
    }

    if (maximum && makeArray(value).length >= parseInt(maximum, 10)) {
      addError(
        i18n("select_kit.max_content_reached", {
          count: parseInt(maximum, 10),
        })
      );
      return false;
    }

    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    filter = filter.replace(filterRegexp, "").trim().toLowerCase();

    if (termMatchesForbidden) {
      return false;
    }

    const toLowerCaseOrUndefined = (string) => {
      return isEmpty(string) ? undefined : string.toLowerCase();
    };

    const inCollection = content
      .map((c) => toLowerCaseOrUndefined(getValue(c)))
      .filter(Boolean)
      .includes(filter);

    const inSelection = (value || [])
      .map((s) => toLowerCaseOrUndefined(s))
      .filter(Boolean)
      .includes(filter);

    if (inCollection || inSelection) {
      return false;
    }

    return true;
  }

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
}
