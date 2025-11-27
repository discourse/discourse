import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { removeValueFromArray } from "discourse/lib/array-tools";

export default class AdminEmbeddingIndexController extends Controller {
  @service site;
  @controller adminEmbedding;

  get embedding() {
    return this.adminEmbedding.embedding;
  }

  get showEmbeddingCode() {
    return this.site.desktopView;
  }

  get embeddingCode() {
    const html = `<div id='discourse-comments'></div>
  <meta name='discourse-username' content='DISCOURSE_USERNAME'>

  <script type="text/javascript">
    DiscourseEmbed = {
      discourseUrl: '${this.embedding.base_url}/',
      discourseEmbedUrl: 'EMBED_URL',
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
  deleteHost(host) {
    removeValueFromArray(this.embedding.embeddable_hosts, host);
  }
}
