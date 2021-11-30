import Component from "@ember/component";
import { afterRender } from "discourse-common/utils/decorators";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { ajax } from "discourse/lib/ajax";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";

export default Component.extend({
  didRender() {
    this._loadOneboxes();
    this._resolveUrls();
  },

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
  },

  @afterRender
  _resolveUrls() {
    resolveAllShortUrls(ajax, this.siteSettings, this.element, this.opts);
  },
});
