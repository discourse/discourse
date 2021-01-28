import Component from "@ember/component";
import { afterRender } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { cookAsync } from "discourse/lib/text";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";

const CookText = Component.extend({
  cooked: null,

  didReceiveAttrs() {
    this._super(...arguments);
    cookAsync(this.rawText).then((cooked) => {
      this.set("cooked", cooked);
      if (this.paintOneboxes) {
        this._loadOneboxes();
      }
      this._resolveUrls();
    });
  },

  @afterRender
  _loadOneboxes() {
    const refresh = false;

    loadOneboxes(
      this.element,
      ajax,
      this.topicId,
      this.categoryId,
      this.siteSettings.max_oneboxes_per_post,
      refresh
    );
  },

  @afterRender
  _resolveUrls() {
    resolveAllShortUrls(ajax, this.siteSettings, this.element, this.opts);
  },
});

CookText.reopenClass({ positionalParams: ["rawText"] });

export default CookText;
