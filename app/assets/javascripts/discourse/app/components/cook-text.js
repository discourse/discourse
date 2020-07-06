import Component from "@ember/component";
import { cookAsync } from "discourse/lib/text";
import { ajax } from "discourse/lib/ajax";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";

const CookText = Component.extend({
  cooked: null,

  didReceiveAttrs() {
    this._super(...arguments);
    cookAsync(this.rawText).then(cooked => {
      this.set("cooked", cooked);

      if (this.element && !this.isDestroying && !this.isDestroyed) {
        return resolveAllShortUrls(ajax, this.siteSettings, this.element);
      }
    });
  }
});

CookText.reopenClass({ positionalParams: ["rawText"] });

export default CookText;
