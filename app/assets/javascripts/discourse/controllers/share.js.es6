import Sharing from 'discourse/lib/sharing';
import { longDateNoYear } from 'discourse/lib/formatter';

export default Ember.Controller.extend({
  needs: ['topic'],
  title: Ember.computed.alias('controllers.topic.model.title'),

  displayDate: function() {
    return longDateNoYear(new Date(this.get('date')));
  }.property('date'),

  // Close the share controller
  actions: {
    close: function() {
      this.setProperties({ link: '', postNumber: '' });
      return false;
    },

    share: function(source) {
      var url = source.generateUrl(this.get('link'), this.get('title'));
      if (source.shouldOpenInPopup) {
        window.open(url, '', 'menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=' + (source.popupHeight || 315));
      } else {
        window.open(url, '_blank');
      }
    }
  },

  sources: function() {
    return Sharing.activeSources(this.siteSettings.share_links);
  }.property()
});
