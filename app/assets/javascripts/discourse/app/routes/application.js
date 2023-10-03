import cookie from "discourse/lib/cookie";
import DiscourseURL, { userPath } from "discourse/lib/url";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { findAll } from "discourse/models/login-method";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";
import logout from "discourse/lib/logout";
import mobile from "discourse/lib/mobile";
import { inject as service } from "@ember/service";
import { setting } from "discourse/lib/computed";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";
import KeyboardShortcutsHelp from "discourse/components/modal/keyboard-shortcuts-help";
import NotActivatedModal from "../components/modal/not-activated";
import ForgotPassword from "discourse/components/modal/forgot-password";
import deprecated from "discourse-common/lib/deprecated";
import LoginModal from "discourse/components/modal/login";

function unlessStrictlyReadOnly(method, message) {
  return function () {
    if (this.site.isReadOnly && !this.site.isStaffWritesOnly) {
      this.dialog.alert(message);
    } else {
      this[method]();
    }
  };
}

const ApplicationRoute = DiscourseRoute.extend({
  siteTitle: setting("title"),
  shortSiteDescription: setting("short_site_description"),
  documentTitle: service(),
  dialog: service(),
  composer: service(),
  modal: service(),
  loadingSlider: service(),
  router: service(),
  siteSettings: service(),

  get includeExternalLoginMethods() {
    return (
      !this.siteSettings.enable_local_logins &&
      this.externalLoginMethods.length === 1
    );
  },

  get externalLoginMethods() {
    return findAll();
  },

  @action
  loading(transition) {
    if (this.loadingSlider.enabled) {
      this.loadingSlider.transitionStarted();
      transition.promise.finally(() => {
        this.loadingSlider.transitionEnded();
      });
      return false;
    } else {
      return true; // Use native ember loading implementation
    }
  },

  actions: {
    toggleAnonymous() {
      ajax(userPath("toggle-anon"), { type: "POST" }).then(() => {
        window.location.reload();
      });
    },

    toggleMobileView() {
      mobile.toggleMobileView();
    },

    toggleSidebar() {
      this.controllerFor("application").send("toggleSidebar");
    },

    logout: unlessStrictlyReadOnly(
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
      return this.composer.open({
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
        return this.router.transitionTo("exception-unknown");
      }

      exceptionController.setProperties({
        lastTransition: transition,
        thrown: xhrOrErr,
      });

      this.intermediateTransitionTo("exception");
      return true;
    },

    showLogin: unlessStrictlyReadOnly(
      "handleShowLogin",
      I18n.t("read_only_mode.login_disabled")
    ),

    showCreateAccount(createAccountProps = {}) {
      if (this.site.isReadOnly) {
        this.dialog.alert(I18n.t("read_only_mode.login_disabled"));
      } else {
        this.handleShowCreateAccount(createAccountProps);
      }
    },

    showForgotPassword() {
      this.modal.show(ForgotPassword);
    },

    showNotActivated(props) {
      this.modal.show(NotActivatedModal, { model: props });
    },

    showUploadSelector() {
      document.getElementById("file-uploader").click();
    },

    showKeyboardShortcutsHelp() {
      this.modal.show(KeyboardShortcutsHelp);
    },

    // Close the current modal, and destroy its state.
    closeModal(initiatedBy) {
      return this.modal.close(initiatedBy);
    },

    /**
      Hide the modal, but keep it with all its state so that it can be shown again later.
      This is useful if you want to prompt for confirmation. hideModal, ask "Are you sure?",
      user clicks "No", reopenModal. If user clicks "Yes", be sure to call closeModal.
    **/
    hideModal() {
      return this.modal.hide();
    },

    reopenModal() {
      return this.modal.reopen();
    },

    editCategory(category) {
      DiscourseURL.routeTo(`/c/${Category.slugFor(category)}/edit`);
    },

    checkEmail(user) {
      user.checkEmail();
    },

    createNewTopicViaParams(title, body, categoryId, tags) {
      deprecated(
        "createNewTopicViaParam on the application route is deprecated. Use the composer service instead",
        { id: "discourse.createNewTopicViaParams" }
      );
      getOwnerWithFallback(this).lookup("service:composer").openNewTopic({
        title,
        body,
        categoryId,
        tags,
      });
    },

    createNewMessageViaParams({
      recipients = "",
      topicTitle = "",
      topicBody = "",
      hasGroups = false,
    } = {}) {
      deprecated(
        "createNewMessageViaParams on the application route is deprecated. Use the composer service instead",
        { id: "discourse.createNewMessageViaParams" }
      );
      getOwnerWithFallback(this).lookup("service:composer").openNewMessage({
        recipients,
        title: topicTitle,
        body: topicBody,
        hasGroups,
      });
    },
  },

  handleShowLogin() {
    if (this.siteSettings.enable_discourse_connect) {
      const returnPath = cookie("destination_url")
        ? getURL("/")
        : encodeURIComponent(window.location.pathname);
      window.location = getURL("/session/sso?return_path=" + returnPath);
    } else {
      this.modal.show(LoginModal, {
        model: {
          ...(this.includeExternalLoginMethods && {
            isExternalLogin: true,
            externalLoginMethod: this.externalLoginMethods[0],
          }),
          showNotActivated: (props) => this.send("showNotActivated", props),
          showCreateAccount: (props) => this.send("showCreateAccount", props),
          canSignUp: this.controller.canSignUp,
        },
      });
    }
  },

  handleShowCreateAccount(createAccountProps) {
    if (this.siteSettings.enable_discourse_connect) {
      const returnPath = encodeURIComponent(window.location.pathname);
      window.location = getURL("/session/sso?return_path=" + returnPath);
    } else {
      if (this.includeExternalLoginMethods) {
        // we will automatically redirect to the external auth service
        this.modal.show(LoginModal, {
          model: {
            isExternalLogin: true,
            externalLoginMethod: this.externalLoginMethods[0],
            signup: true,
          },
        });
      } else {
        const createAccount = showModal("create-account", {
          modalClass: "create-account",
          titleAriaElementId: "create-account-title",
        });
        createAccount.setProperties(createAccountProps);
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
