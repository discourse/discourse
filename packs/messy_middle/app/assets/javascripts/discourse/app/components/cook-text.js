import Component from "@ember/component";
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
    });
  },

  didRender() {
    this._super(...arguments);

    if (this.paintOneboxes) {
      loadOneboxes(
        this.element,
        ajax,
        this.topicId,
        this.categoryId,
        this.siteSettings.max_oneboxes_per_post,
        false // refresh
      );
    }

    resolveAllShortUrls(ajax, this.siteSettings, this.element, this.opts);
  },
});

CookText.reopenClass({ positionalParams: ["rawText"] });

export default CookText;
