import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  saved: false,
  embedding: null,

  // show settings if we have at least one created host
  @computed('embedding.embeddable_hosts.@each.isCreated')
  showSecondary() {
    const hosts = this.get('embedding.embeddable_hosts');
    return hosts.length && hosts.findProperty('isCreated');
  },

  @computed('embedding.base_url')
  embeddingCode(baseUrl) {

    const html =
`<div id='discourse-comments'></div>

<script type="text/javascript">
  DiscourseEmbed = { discourseUrl: '${baseUrl}/',
                     discourseEmbedUrl: 'REPLACE_ME' };

  (function() {
    var d = document.createElement('script'); d.type = 'text/javascript'; d.async = true;
    d.src = DiscourseEmbed.discourseUrl + 'javascripts/embed.js';
    (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(d);
  })();
</script>`;

    return html;
  },

  actions: {
    saveChanges() {
      const embedding = this.get('embedding');
      const updates = embedding.getProperties(embedding.get('fields'));

      this.set('saved', false);
      this.get('embedding').update(updates).then(() => {
        this.set('saved', true);
      }).catch(popupAjaxError);
    },

    addHost() {
      const host = this.store.createRecord('embeddable-host');
      this.get('embedding.embeddable_hosts').pushObject(host);
    },

    deleteHost(host) {
      this.get('embedding.embeddable_hosts').removeObject(host);
    }
  }
});
