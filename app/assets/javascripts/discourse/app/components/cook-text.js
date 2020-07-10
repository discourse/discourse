import Component from "@ember/component";
import { afterRender } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { cookAsync } from "discourse/lib/text";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";

const CookText = Component.extend({
  cooked: null,

  didReceiveAttrs() {
    this._super(...arguments);
    cookAsync(this.rawText).then(cooked => {
      this.set("cooked", cooked);
      this._resolveUrls();
    });
  },

  @afterRender
  _resolveUrls() {
    resolveAllShortUrls(ajax, this.siteSettings, this.element, this.opts);
  }
});

CookText.reopenClass({ positionalParams: ["rawText"] });

export default CookText;
