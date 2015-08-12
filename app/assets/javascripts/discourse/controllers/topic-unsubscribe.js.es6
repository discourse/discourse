import ObjectController from "discourse/controllers/object";

export default ObjectController.extend({

  stopNotificiationsText: function() {
    return I18n.t("topic.unsubscribe.stop_notifications", { title: this.get("model.fancyTitle") });
  }.property("model.fancyTitle"),

})
