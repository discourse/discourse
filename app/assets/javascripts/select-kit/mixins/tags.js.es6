const { run, get } = Ember;
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Mixin.create({
  willDestroyElement() {
    this._super();

    const searchDebounce = this.get("searchDebounce");
    if (searchDebounce) run.cancel(searchDebounce);
  },

  searchTags(url, data, callback) {
    const self = this;

    this.startLoading();

    return ajax(Discourse.getURL(url), {
      quietMillis: 200,
      cache: true,
      dataType: "json",
      data
    }).then(json => {
      self.set("asyncContent", callback(self, json));
    }).catch(error => {
      popupAjaxError(error);
    })
    .finally(() => {
      self.stopLoading();
      self.autoHighlight();
    });
  },

  validateCreate(term) {
    if (this.get("limitReached") || !this.site.get("can_create_tag")) {
      return false;
    }

    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g");
    term = term.replace(filterRegexp, "").trim().toLowerCase();

    if (!term.length || this.get("termMatchesForbidden")) {
      return false;
    }

    if (this.get("siteSettings.max_tag_length") < term.length) {
      return false;
    }

    if (this.get("asyncContent").map(c => get(c, "id")).includes(term)) {
      return false;
    }

    return true;
  },
});
