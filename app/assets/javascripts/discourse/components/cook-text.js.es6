import { cookAsync } from "discourse/lib/text";
import { ajax } from "discourse/lib/ajax";

const CookText = Ember.Component.extend({
  tagName: "",
  cooked: null,

  didReceiveAttrs() {
    this._super(...arguments);
    cookAsync(this.get("rawText")).then(cooked => {
      this.set("cooked", cooked);
      // no choice but to defer this cause
      // pretty text may only be loaded now
      Em.run.next(() =>
        window
          .requireModule("pretty-text/image-short-url")
          .resolveAllShortUrls(ajax)
      );
    });
  }
});

CookText.reopenClass({ positionalParams: ["rawText"] });

export default CookText;
