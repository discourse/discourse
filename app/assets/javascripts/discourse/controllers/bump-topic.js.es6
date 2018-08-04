import ModalFunctionality from "discourse/mixins/modal-functionality";
import computed from "ember-addons/ember-computed-decorators";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";

// Modal for enabling/disabling bumping of topics and changing the bump date
export default Ember.Controller.extend(ModalFunctionality, {
  topicController: Ember.inject.controller("topic"),
  saving: false,
  date: "",
  time: "",
  skipBump: false,
  updateDate: false,

  @computed("saving")
  buttonTitle(saving) {
    return saving ? I18n.t("saving") : I18n.t("topic.bump.action");
  },

  @computed("date", "time")
  bumpedAt(date, time) {
    return moment(date + " " + time, "YYYY-MM-DD HH:mm:ss");
  },

  @computed("bumpedAt")
  validBumpDate(bumpedAt) {
    return moment().diff(bumpedAt, "minutes") < 0;
  },

  @computed("saving", "date", "validBumpDate", "skipBump", "updateDate")
  buttonDisabled() {
    if (this.get("saving")) return true;

    if (this.get("updateDate")) {
      return this.get("validBumpDate") || Ember.isEmpty(this.get("date"));
    }

    const topic = this.get("topicController.model");
    return this.get("skipBump") === Boolean(topic.skip_bump);
  },

  onShow() {
    const topic = this.get("topicController.model");
    const bumpedAt = moment(topic.bumped_at);

    this.setProperties({
      saving: false,
      skipBump: Boolean(topic.skip_bump),
      updateDate: false,
      date: bumpedAt.format("YYYY-MM-DD"),
      time: bumpedAt.format("HH:mm")
    });
  },

  actions: {
    save: function() {
      this.set("saving", true);
      const self = this,
        topic = this.get("topicController.model");

      Topic.updateBump(
        topic.get("id"),
        this.get("skipBump"),
        this.get("updateDate") ? this.get("bumpedAt").unix() : null
      )
        .then(function() {
          self.send("closeModal");
          Em.run.next(() => {
            DiscourseURL.routeTo(topic.get("url"));
          });
        })
        .catch(function() {
          self.flash(I18n.t("topic.bump.error"), "alert-error");
          self.set("saving", false);
        });
      return false;
    }
  }
});
