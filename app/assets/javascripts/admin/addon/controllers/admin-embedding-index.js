import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

export default class AdminEmbeddingIndexController extends Controller {
  @service router;
  @service site;
  @controller adminEmbedding;
  @alias("adminEmbedding.embedding") embedding;

  get showEmbeddingCode() {
    const hosts = this.get("embedding.embeddable_hosts");
    return hosts.length > 0 && !this.site.isMobileDevice;
  }

  @discourseComputed("embedding.base_url")
  embeddingCode(baseUrl) {
    const html = `<div id='discourse-comments'></div>
  <meta name='discourse-username' content='DISCOURSE_USERNAME'>

  <script type="text/javascript">
    DiscourseEmbed = {
      discourseUrl: '${baseUrl}/',
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
    this.get("embedding.embeddable_hosts").removeObject(host);
  }
}
