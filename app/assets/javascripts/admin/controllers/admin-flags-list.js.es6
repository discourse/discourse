import FlaggedPost from 'admin/models/flagged-post';

export default Ember.ArrayController.extend({
  query: null,

  adminOldFlagsView: Em.computed.equal("query", "old"),
  adminActiveFlagsView: Em.computed.equal("query", "active"),

  actions: {
    disagreeFlags(flaggedPost) {
      var self = this;
      flaggedPost.disagreeFlags().then(function () {
        self.removeObject(flaggedPost);
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    deferFlags(flaggedPost) {
      var self = this;
      flaggedPost.deferFlags().then(function () {
        self.removeObject(flaggedPost);
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    doneTopicFlags(item) {
      this.send("disagreeFlags", item);
    },

    loadMore(){
      const flags = this.get('model');
      return FlaggedPost.findAll(this.get('query'), flags.length+1).then(data => {
        if (data.length===0) {
          flags.set("allLoaded",true);
        }
        flags.addObjects(data);
      });
    }
  }

});
