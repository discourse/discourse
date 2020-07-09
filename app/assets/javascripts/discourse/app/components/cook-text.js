import Component from "@ember/component";
import { cookAsync } from "discourse/lib/text";
import { ajax } from "discourse/lib/ajax";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import { afterRender } from "discourse-common/utils/decorators";

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
    resolveAllShortUrls(ajax, this.siteSettings, this.element);
  }
});

CookText.reopenClass({ positionalParams: ["rawText"] });

export default CookText;
