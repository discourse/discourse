import Component from "@ember/component";
import { on } from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";
import LogsNotice from "discourse/services/logs-notice";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    rerenderTriggers: ["site.isReadOnly", "siteSettings.disable_emails"],

    buildBuffer(buffer) {
      let notices = [];

      if ($.cookie("dosp") === "1") {
        $.removeCookie("dosp", { path: "/" });
        notices.push([I18n.t("forced_anonymous"), "forced-anonymous"]);
      }

      if (this.session.get("safe_mode")) {
        notices.push([I18n.t("safe_mode.enabled"), "safe-mode"]);
      }

      if (this.site.get("isReadOnly")) {
        notices.push([I18n.t("read_only_mode.enabled"), "alert-read-only"]);
      }

      if (
        this.siteSettings.disable_emails === "yes" ||
        this.siteSettings.disable_emails === "non-staff"
      ) {
        notices.push([I18n.t("emails_are_disabled"), "alert-emails-disabled"]);
      }

      if (this.site.get("wizard_required")) {
        const requiredText = I18n.t("wizard_required", {
          url: Discourse.getURL("/wizard")
        });
        notices.push([requiredText, "alert-wizard"]);
      }

      if (
        this.currentUser &&
        this.currentUser.get("staff") &&
        this.siteSettings.bootstrap_mode_enabled
      ) {
        if (this.siteSettings.bootstrap_mode_min_users > 0) {
          notices.push([
            I18n.t("bootstrap_mode_enabled", {
              min_users: this.siteSettings.bootstrap_mode_min_users
            }),
            "alert-bootstrap-mode"
          ]);
        } else {
          notices.push([
            I18n.t("bootstrap_mode_disabled"),
            "alert-bootstrap-mode"
          ]);
        }
      }

      if (!_.isEmpty(this.siteSettings.global_notice)) {
        notices.push([this.siteSettings.global_notice, "alert-global-notice"]);
      }

      if (!LogsNotice.currentProp("hidden")) {
        notices.push([
          LogsNotice.currentProp("message"),
          "alert-logs-notice",
          `<div class='close'>${iconHTML("times")}</div>`
        ]);
      }

      if (notices.length > 0) {
        buffer.push(
          notices
            .map(n => {
              var html = `<div class='row'><div class='alert alert-info ${
                n[1]
              }'>`;
              if (n[2]) html += n[2];
              html += `${n[0]}</div></div>`;
              return html;
            })
            .join("")
        );
      }
    },

    @on("didInsertElement")
    _setupLogsNotice() {
      this._boundRerenderBuffer = Ember.run.bind(this, this.rerenderBuffer);
      LogsNotice.current().addObserver("hidden", this._boundRerenderBuffer);

      this._boundResetCurrentProp = Ember.run.bind(
        this,
        this._resetCurrentProp
      );
      $(this.element).on(
        "click.global-notice",
        ".alert-logs-notice .close",
        this._boundResetCurrentProp
      );
    },

    @on("willDestroyElement")
    _teardownLogsNotice() {
      if (this._boundResetCurrentProp) {
        $(this.element).off("click.global-notice", this._boundResetCurrentProp);
      }

      if (this._boundRerenderBuffer) {
        LogsNotice.current().removeObserver(
          "hidden",
          this._boundRerenderBuffer
        );
      }
    },

    _resetCurrentProp() {
      LogsNotice.currentProp("text", "");
    }
  })
);
