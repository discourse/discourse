import DiscourseURL, { userPath } from "discourse/lib/url";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import OpenComposer from "discourse/mixins/open-composer";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import { findAll } from "discourse/models/login-method";
import { getOwner } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";
import logout from "discourse/lib/logout";
import mobile from "discourse/lib/mobile";
import { inject as service } from "@ember/service";
import { setting } from "discourse/lib/computed";
import showModal from "discourse/lib/show-modal";

function unlessReadOnly(method, message) {
  return function () {
    if (this.site.get("isReadOnly")) {
      bootbox.alert(message);
    } else {
      this[method]();
    }
  };
}

const ApplicationRoute = DiscourseRoute.extend(OpenComposer, {
  siteTitle: setting("title"),
  shortSiteDescription: setting("short_site_description"),
  documentTitle: service(),

  actions: {
    toggleAnonymous() {
      ajax(userPath("toggle-anon"), { type: "POST" }).then(() => {
        window.location.reload();
      });
    },

    toggleMobileView() {
      mobile.toggleMobileView();
    },

    logout: unlessReadOnly(
      "_handleLogout",
      I18n.t("read_only_mode.logout_disabled")
    ),

    _collectTitleTokens(tokens) {
      tokens.push(this.siteTitle);
      if (
        (window.location.pathname === getURL("/") ||
          window.location.pathname === getURL("/login")) &&
        this.shortSiteDescription !== ""
      ) {
        tokens.push(this.shortSiteDescription);
      }
      this.documentTitle.setTitle(tokens.join(" - "));
    },

    postWasEnqueued(details) {
      showModal("post-enqueued", {
        model: details,
        title: "review.approval.title",
      });
    },

    composePrivateMessage(user, post) {
      const recipients = user ? user.get("username") : "";
      const reply = post
        ? `${window.location.protocol}//${window.location.host}${post.url}`
        : null;
      const title = post
        ? I18n.t("composer.reference_topic_title", {
            title: post.topic.title,
          })
        : null;

      // used only once, one less dependency
      return this.controllerFor("composer").open({
        action: Composer.PRIVATE_MESSAGE,
        recipients,
        archetypeId: "private_message",
        draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
        draftSequence: 0,
        reply,
        title,
      });
    },

    error(err, transition) {
      const xhrOrErr = err.jqXHR ? err.jqXHR : err;
      const exceptionController = this.controllerFor("exception");

      const c = window.console;
      if (c && c.error) {
        c.error(xhrOrErr);
      }

      if (xhrOrErr && xhrOrErr.status === 404) {
        return this.transitionTo("exception-unknown");
      }

      exceptionController.setProperties({
        lastTransition: transition,
        thrown: xhrOrErr,
      });

      this.intermediateTransitionTo("exception");
      return true;
    },

    showLogin: unlessReadOnly(
      "handleShowLogin",
      I18n.t("read_only_mode.login_disabled")
    ),

    showCreateAccount: unlessReadOnly(
      "handleShowCreateAccount",
      I18n.t("read_only_mode.login_disabled")
    ),

    showForgotPassword() {
      this.controllerFor("forgot-password").setProperties({
        offerHelp: null,
        helpSeen: false,
      });
      showModal("forgotPassword", { title: "forgot_password.title" });
    },

    showNotActivated(props) {
      showModal("not-activated", { title: "log_in" }).setProperties(props);
    },

    showUploadSelector() {
      document.getElementById("file-uploader").click();
    },

    showKeyboardShortcutsHelp() {
      showModal("keyboard-shortcuts-help", {
        title: "keyboard_shortcuts_help.title",
      });
    },

    // Close the current modal, and destroy its state.
    closeModal(initiatedBy) {
      const route = getOwner(this).lookup("route:application");
      let modalController = route.controllerFor("modal");
      const controllerName = modalController.get("name");

      if (controllerName) {
        const controller = getOwner(this).lookup(
          `controller:${controllerName}`
        );
        if (controller && controller.beforeClose) {
          if (false === controller.beforeClose()) {
            return;
          }
        }
      }

      this.render("hide-modal", { into: "modal", outlet: "modalBody" });

      if (controllerName) {
        const controller = getOwner(this).lookup(
          `controller:${controllerName}`
        );

        if (controller) {
          this.appEvents.trigger("modal:closed", {
            name: controllerName,
            controller,
          });

          if (controller.onClose) {
            controller.onClose({
              initiatedByCloseButton: initiatedBy === "initiatedByCloseButton",
              initiatedByClickOut: initiatedBy === "initiatedByClickOut",
              initiatedByESC: initiatedBy === "initiatedByESC",
            });
          }
        }
        modalController.set("name", null);
      }
    },

    /**
      Hide the modal, but keep it with all its state so that it can be shown again later.
      This is useful if you want to prompt for confirmation. hideModal, ask "Are you sure?",
      user clicks "No", reopenModal. If user clicks "Yes", be sure to call closeModal.
    **/
    hideModal() {
      $(".d-modal.fixed-modal").modal("hide");
    },

    reopenModal() {
      $(".d-modal.fixed-modal").modal("show");
    },

    editCategory(category) {
      DiscourseURL.routeTo(`/c/${Category.slugFor(category)}/edit`);
    },

    checkEmail(user) {
      user.checkEmail();
    },

    changeBulkTemplate(w) {
      const controllerName = w.replace("modal/", "");
      const controller = getOwner(this).lookup("controller:" + controllerName);
      this.render(w, {
        into: "modal/topic-bulk-actions",
        outlet: "bulkOutlet",
        controller: controller ? controllerName : "topic-bulk-actions",
      });
    },

    createNewTopicViaParams(title, body, category_id, tags) {
      this.openComposerWithTopicParams(
        this.controllerFor("discovery/topics"),
        title,
        body,
        category_id,
        tags
      );
    },

    createNewMessageViaParams({
      recipients = [],
      topicTitle = "",
      topicBody = "",
      hasGroups = false,
    } = {}) {
      this.openComposerWithMessageParams({
        recipients,
        topicTitle,
        topicBody,
        hasGroups,
      });
    },
  },

  renderTemplate() {
    this.render("application");
    this.render("user-card", { into: "application", outlet: "user-card" });
    this.render("modal", { into: "application", outlet: "modal" });
    this.render("composer", { into: "application", outlet: "composer" });
  },

  handleShowLogin() {
    if (this.siteSettings.enable_discourse_connect) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = getURL("/session/sso?return_path=" + returnPath);
    } else {
      this._autoLogin("login", "login-modal", {
        notAuto: () => this.controllerFor("login").resetForm(),
      });
    }
  },

  handleShowCreateAccount() {
    if (this.siteSettings.enable_discourse_connect) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = getURL("/session/sso?return_path=" + returnPath);
    } else {
      this._autoLogin("createAccount", "create-account", {
        signup: true,
        titleAriaElementId: "create-account-title",
      });
    }
  },

  _autoLogin(
    modal,
    modalClass,
    { notAuto = null, signup = false, titleAriaElementId = null } = {}
  ) {
    const methods = findAll();

    if (!this.siteSettings.enable_local_logins && methods.length === 1) {
      this.controllerFor("login").send("externalLogin", methods[0], {
        signup,
      });
    } else {
      showModal(modal, { titleAriaElementId });
      this.controllerFor("modal").set("modalClass", modalClass);
      if (notAuto) {
        notAuto();
      }
    }
  },

  _handleLogout() {
    if (this.currentUser) {
      this.currentUser
        .destroySession()
        .then((response) => logout({ redirect: response["redirect_url"] }));
    }
  },
});

export default ApplicationRoute;
