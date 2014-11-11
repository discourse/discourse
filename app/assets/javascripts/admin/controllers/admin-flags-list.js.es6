export default Ember.ArrayController.extend({
  query: null,

  adminOldFlagsView: Em.computed.equal("query", "old"),
  adminActiveFlagsView: Em.computed.equal("query", "active"),

  actions: {
    disagreeFlags: function (flaggedPost) {
      var self = this;
      flaggedPost.disagreeFlags().then(function () {
        self.removeObject(flaggedPost);
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    deferFlags: function (flaggedPost) {
      var self = this;
      flaggedPost.deferFlags().then(function () {
        self.removeObject(flaggedPost);
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    doneTopicFlags: function(item) {
      this.send("disagreeFlags", item);
    },
  },

  loadMore: function(){
    var flags = this.get("model");
    return Discourse.FlaggedPost.findAll(this.get("query"),flags.length+1).then(function(data){
      if(data.length===0){
        flags.set("allLoaded",true);
      }
      flags.addObjects(data);
    });
  }

});
