import TextField from "discourse/components/text-field";
import { on } from "discourse-common/utils/decorators";

export default TextField.extend({
  @on("init")
  _init() {
    // Chrome autocomplete is buggy per:
    // https://bugs.chromium.org/p/chromium/issues/detail?id=987293
    // work around issue while leaving a semi useable honeypot for
    // bots that are running full Chrome
    if (navigator.userAgent.includes("Chrome")) {
      this.set("type", "text");
    } else {
      this.set("type", "password");
    }
  },
});
