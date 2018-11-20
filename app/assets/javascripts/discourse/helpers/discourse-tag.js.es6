import { registerUnbound } from "discourse-common/lib/helpers";
import renderTag from "discourse/lib/render-tag";

export default registerUnbound("discourse-tag", function(name, params) {
  return new Handlebars.SafeString(renderTag(name, params));
});
