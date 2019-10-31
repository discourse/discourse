import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SiteSetting from "admin/models/site-setting";
import SettingComponent from "admin/mixins/setting-component";
import showModal from "discourse/lib/show-modal";
import AboutRoute from "discourse/routes/about";

export default Component.extend(BufferedContent, SettingComponent, {
  updateExistingUsers: null,

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.updateExistingUsers
    });
  },

  actions: {
    update() {
      const defaultUserPreferences = [
        "default_email_digest_frequency",
        "default_include_tl0_in_digests",
        "default_email_level",
        "default_email_messages_level",
        "default_email_mailing_list_mode",
        "default_email_mailing_list_mode_frequency",
        "disable_mailing_list_mode",
        "default_email_previous_replies",
        "default_email_in_reply_to",
        "default_other_new_topic_duration_minutes",
        "default_other_auto_track_topics_after_msecs",
        "default_other_notification_level_when_replying",
        "default_other_external_links_in_new_tab",
        "default_other_enable_quoting",
        "default_other_enable_defer",
        "default_other_dynamic_favicon",
        "default_other_like_notification_frequency",
        "default_topics_automatic_unpin",
        "default_categories_watching",
        "default_categories_tracking",
        "default_categories_muted",
        "default_categories_watching_first_post",
        "default_text_size",
        "default_title_count_mode"
      ];
      const key = this.buffered.get("setting");

      if (defaultUserPreferences.includes(key)) {
        AboutRoute.create()
          .model()
          .then(result => {
            const controller = showModal("site-setting-default-categories", {
              model: {
                count: result.stats.user_count,
                key: key.replace(/_/g, " ")
              },
              admin: true
            });

            controller.set("onClose", () => {
              this.updateExistingUsers = controller.updateExistingUsers;
              this.send("save");
            });
          });
      } else {
        this.send("save");
      }
    }
  }
});
