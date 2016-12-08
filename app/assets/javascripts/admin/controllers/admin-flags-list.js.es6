import FlaggedPost from 'admin/models/flagged-post';

export default Ember.Controller.extend({
  query: null,

  adminOldFlagsView: Em.computed.equal("query", "old"),
  adminActiveFlagsView: Em.computed.equal("query", "active"),

  actions: {
    disagreeFlags(flaggedPost) {
      flaggedPost.disagreeFlags().then(() => {
        this.get('model').removeObject(flaggedPost);
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    deferFlags(flaggedPost) {
      flaggedPost.deferFlags().then(() => {
        this.get('model').removeObject(flaggedPost);
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    doneTopicFlags(item) {
      this.send("disagreeFlags", item);
    },

    loadMore() {
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
