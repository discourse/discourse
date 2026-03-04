import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class StaticPage extends EmberObject {
  // Models shouldn't really be doing Ajax request, but this is a huge speed boost if we
  // preload content.
  static async find(path) {
    const preloaded = document.querySelector(`noscript[data-path="/${path}"]`);
    if (preloaded) {
      const text = preloaded.textContent.match(
        /<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/
      )[1];
      return StaticPage.create({ path, html: text });
    } else {
      const result = await ajax(`/${path}.html`, { dataType: "html" });
      return StaticPage.create({ path, html: result });
    }
  }
}
