import { action } from "@ember/object";
import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminEmbeddingController extends Controller {
  saved = false;
  embedding = null;

  // show settings if we have at least one created host
  @discourseComputed("embedding.embeddable_hosts.@each.isCreated")
  showSecondary() {
    const hosts = this.get("embedding.embeddable_hosts");
    return hosts.length && hosts.findBy("isCreated");
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
  saveChanges() {
    const embedding = this.embedding;
    const updates = embedding.getProperties(embedding.get("fields"));

    this.set("saved", false);
    this.embedding
      .update(updates)
      .then(() => this.set("saved", true))
      .catch(popupAjaxError);
  }

  @action
  addHost() {
    const host = this.store.createRecord("embeddable-host");
    this.get("embedding.embeddable_hosts").pushObject(host);
  }

  @action
  deleteHost(host) {
    this.get("embedding.embeddable_hosts").removeObject(host);
  }
}
