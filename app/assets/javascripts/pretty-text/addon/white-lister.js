import deprecated from "discourse-common/lib/deprecated";
import AllowLister from "pretty-text/allow-lister";
import { DEFAULT_LIST as NEW_DEFAULT_LIST } from "pretty-text/allow-lister";

export default class WhiteLister extends AllowLister {
  constructor(options) {
    deprecated("`WhiteLister` has been replaced with `AllowLister`", {
      since: "2.6.0.beta.4",
      dropFrom: "2.7.0",
    });
    super(options);
  }
}

export const DEFAULT_LIST = NEW_DEFAULT_LIST;
