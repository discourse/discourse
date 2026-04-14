import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";

export default class AdminEmbeddingIndexController extends Controller {
  @service site;
  @service siteSettings;
  @controller adminEmbedding;

  get fullAppMode() {
    return this.siteSettings.embed_full_app;
  }

  get embedding() {
    return this.adminEmbedding.embedding;
  }

  get showEmbeddingCode() {
    return this.site.desktopView;
  }

  get embeddingCode() {
    const fullAppLines = this.fullAppMode
      ? `
      fullApp: true,
      embedHeight: '800px',`
      : "";

    const html = `<div id='discourse-comments'></div>
  <meta name='discourse-username' content='DISCOURSE_USERNAME'>

  <script type="text/javascript">
    DiscourseEmbed = {
      discourseUrl: '${this.embedding.base_url}/',
      discourseEmbedUrl: 'EMBED_URL',${fullAppLines}
      // className: 'CLASS_NAME',
    };

    (function() {
      var d = document.createElement('script'); d.type = 'text/javascript'; d.async = true;
      d.src = DiscourseEmbed.discourseUrl + 'javascripts/embed.js';
      (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(d);
    })();
  </script>`;

    return html;
  }

  @action
  async toggleFullAppMode() {
    const previousValue = this.siteSettings.embed_full_app;
    this.siteSettings.embed_full_app = !previousValue;

    try {
      await SiteSetting.update("embed_full_app", !previousValue);
    } catch (err) {
      this.siteSettings.embed_full_app = previousValue;
      popupAjaxError(err);
    }
  }

  @action
  deleteHost(host) {
    removeValueFromArray(this.embedding.embeddable_hosts, host);
  }
}
