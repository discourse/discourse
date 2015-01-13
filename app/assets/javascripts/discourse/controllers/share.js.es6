import Sharing from 'discourse/lib/sharing';

export default Ember.Controller.extend({
  needs: ['topic'],
  title: Ember.computed.alias('controllers.topic.title'),

  displayDate: function() {
    return Discourse.Formatter.longDateNoYear(new Date(this.get('date')));
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
    return Sharing.activeSources();
  }.property()
});
