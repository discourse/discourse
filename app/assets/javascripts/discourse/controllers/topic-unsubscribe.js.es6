export default Ember.Controller.extend({

  stopNotificiationsText: function() {
    return I18n.t("topic.unsubscribe.stop_notifications", { title: this.get("model.fancyTitle") });
  }.property("model.fancyTitle"),

});
