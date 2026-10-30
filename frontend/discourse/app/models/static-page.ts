import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

/** Successful static-page responses contain a path and HTML body. */
export interface StaticPageFields {
  path: string;
  html: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface StaticPage extends StaticPageFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class StaticPage extends EmberObject {
  /**
   * Models shouldn't really be doing Ajax requests, but preloading content is a huge
   * speed boost. The preload branch assumes non-null text and matching markers.
   */
  static async find(path: string): Promise<StaticPage> {
    const preloaded = document.querySelector(`noscript[data-path="/${path}"]`);
    if (preloaded) {
      const text = preloaded.textContent!.match(
        /<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/
      )![1];
      return StaticPage.create({ path, html: text });
    } else {
      const result = await ajax(`/${path}.html`, { dataType: "html" });
      return StaticPage.create({ path, html: result });
    }
  }
}
