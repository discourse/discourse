import Component from "@ember/component";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import { ajax } from "discourse/lib/ajax";
import { afterRender } from "discourse/lib/decorators";
import { loadOneboxes } from "discourse/lib/load-oneboxes";

export default class PendingPost extends Component {
  didRender() {
    super.didRender(...arguments);
    this._loadOneboxes();
    this._resolveUrls();
  }

  @afterRender
  _loadOneboxes() {
    loadOneboxes(
      this.element,
      ajax,
      this.post.topic_id,
      this.post.category_id,
      this.siteSettings.max_oneboxes_per_post,
      true
    );
  }

  @afterRender
  _resolveUrls() {
    resolveAllShortUrls(ajax, this.siteSettings, this.element, this.opts);
  }
}
