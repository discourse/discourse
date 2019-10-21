import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { setting } from "discourse/lib/computed";
import logout from "discourse/lib/logout";
import showModal from "discourse/lib/show-modal";
import OpenComposer from "discourse/mixins/open-composer";
import Category from "discourse/models/category";
import mobile from "discourse/lib/mobile";
import { findAll } from "discourse/models/login-method";
import { getOwner } from "discourse-common/lib/get-owner";
import { userPath } from "discourse/lib/url";
import Composer from "discourse/models/composer";

function unlessReadOnly(method, message) {
  return function() {
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

  actions: {
    toggleAnonymous() {
      ajax(userPath("toggle-anon"), { method: "POST" }).then(() => {
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
        (window.location.pathname === Discourse.getURL("/") ||
          window.location.pathname === Discourse.getURL("/login")) &&
        this.shortSiteDescription !== ""
      ) {
        tokens.push(this.shortSiteDescription);
      }
      Discourse.set("_docTitle", tokens.join(" - "));
    },

    // Ember doesn't provider a router `willTransition` event so let's make one
    willTransition() {
      var router = getOwner(this).lookup("router:main");
      Ember.run.once(router, router.trigger, "willTransition");
      return this._super(...arguments);
    },

    postWasEnqueued(details) {
      showModal("post-enqueued", {
        model: details,
        title: "review.approval.title"
      });
    },

    composePrivateMessage(user, post) {
      const recipient = user ? user.get("username") : "",
        reply = post
          ? `${window.location.protocol}//${window.location.host}${post.url}`
          : null,
        title = post
          ? I18n.t("composer.reference_topic_title", {
              title: post.topic.title
            })
          : null;

      // used only once, one less dependency
      return this.controllerFor("composer").open({
        action: Composer.PRIVATE_MESSAGE,
        usernames: recipient,
        archetypeId: "private_message",
        draftKey: Composer.NEW_PRIVATE_MESSAGE_KEY,
        reply,
        title
      });
    },

    error(err, transition) {
      let xhr = {};
      if (err.jqXHR) {
        xhr = err.jqXHR;
      }

      const xhrOrErr = err.jqXHR ? xhr : err;

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
        thrown: xhrOrErr
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
        helpSeen: false
      });
      showModal("forgotPassword", { title: "forgot_password.title" });
    },

    showNotActivated(props) {
      showModal("not-activated", { title: "log_in" }).setProperties(props);
    },

    showUploadSelector(toolbarEvent) {
      showModal("uploadSelector").setProperties({
        toolbarEvent,
        imageUrl: null,
        imageLink: null
      });
    },

    showKeyboardShortcutsHelp() {
      showModal("keyboard-shortcuts-help", {
        title: "keyboard_shortcuts_help.title"
      });
    },

    // Close the current modal, and destroy its state.
    closeModal() {
      this.render("hide-modal", { into: "modal", outlet: "modalBody" });

      const route = getOwner(this).lookup("route:application");
      let modalController = route.controllerFor("modal");
      const controllerName = modalController.get("name");

      if (controllerName) {
        const controller = getOwner(this).lookup(
          `controller:${controllerName}`
        );
        if (controller && controller.onClose) {
          controller.onClose();
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
      Category.reloadById(category.get("id")).then(atts => {
        const model = this.store.createRecord("category", atts.category);
        model.setupGroupsAndPermissions();
        this.site.updateCategory(model);
        showModal("edit-category", { model });
        this.controllerFor("edit-category").set("selectedTab", "general");
      });
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
        controller: controller ? controllerName : "topic-bulk-actions"
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

    createNewMessageViaParams(username, title, body) {
      this.openComposerWithMessageParams(username, title, body);
    }
  },

  activate() {
    this._super(...arguments);
    Ember.run.next(function() {
      // Support for callbacks once the application has activated
      ApplicationRoute.trigger("activate");
    });
  },

  renderTemplate() {
    this.render("application");
    this.render("user-card", { into: "application", outlet: "user-card" });
    this.render("modal", { into: "application", outlet: "modal" });
    this.render("composer", { into: "application", outlet: "composer" });
  },

  handleShowLogin() {
    if (this.siteSettings.enable_sso) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = Discourse.getURL(
        "/session/sso?return_path=" + returnPath
      );
    } else {
      this._autoLogin("login", "login-modal", () =>
        this.controllerFor("login").resetForm()
      );
    }
  },

  handleShowCreateAccount() {
    if (this.siteSettings.enable_sso) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = Discourse.getURL(
        "/session/sso?return_path=" + returnPath
      );
    } else {
      this._autoLogin("createAccount", "create-account");
    }
  },

  _autoLogin(modal, modalClass, notAuto) {
    const methods = findAll();

    if (!this.siteSettings.enable_local_logins && methods.length === 1) {
      this.controllerFor("login").send("externalLogin", methods[0]);
    } else {
      showModal(modal);
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
        .then(() => logout(this.siteSettings, this.keyValueStore));
    }
  }
});

RSVP.EventTarget.mixin(ApplicationRoute);
export default ApplicationRoute;
