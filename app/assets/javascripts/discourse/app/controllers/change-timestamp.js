import { inject as controller } from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import Topic from "discourse/models/topic";
import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";

// Modal related to changing the timestamp of posts
export default Modal.extend({
  topicController: controller("topic"),
  saving: false,
  date: "",
  time: "",

  @discourseComputed("saving")
  buttonTitle(saving) {
    return saving ? I18n.t("saving") : I18n.t("topic.change_timestamp.action");
  },

  @discourseComputed("date", "time")
  createdAt(date, time) {
    return moment(`${date} ${time}`, "YYYY-MM-DD HH:mm:ss");
  },

  @discourseComputed("createdAt")
  validTimestamp(createdAt) {
    return moment().diff(createdAt, "minutes") < 0;
  },

  @discourseComputed("saving", "date", "validTimestamp")
  buttonDisabled(saving, date, validTimestamp) {
    if (saving || validTimestamp) {
      return true;
    }
    return isEmpty(date);
  },

  onShow() {
    this.set("date", moment().format("YYYY-MM-DD"));
  },

  actions: {
    changeTimestamp() {
      this.set("saving", true);

      const topic = this.topicController.model;

      Topic.changeTimestamp(topic.id, this.createdAt.unix())
        .then(() => {
          this.send("closeModal");
          this.setProperties({ date: "", time: "", saving: false });
          next(() => DiscourseURL.routeTo(topic.url));
        })
        .catch(() =>
          this.flash(I18n.t("topic.change_timestamp.error"), "error")
        )
        .finally(() => this.set("saving", false));

      return false;
    },
  },
});
