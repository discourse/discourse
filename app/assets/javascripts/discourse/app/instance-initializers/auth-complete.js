import EmberObject from "@ember/object";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import CreateAccount from "discourse/components/modal/create-account";
import LoginModal from "discourse/components/modal/login";
import cookie, { removeCookie } from "discourse/lib/cookie";
import DiscourseUrl from "discourse/lib/url";
import I18n from "discourse-i18n";

// This is happening outside of the app via popup
const AuthErrors = [
  "requires_invite",
  "awaiting_approval",
  "awaiting_activation",
  "admin_not_allowed_from_ip_address",
  "not_allowed_from_ip_address",
];

const beforeAuthCompleteCallbacks = [];

export function addBeforeAuthCompleteCallback(fn) {
  beforeAuthCompleteCallbacks.push(fn);
}

export function resetBeforeAuthCompleteCallbacks() {
  beforeAuthCompleteCallbacks.length = 0;
}

export default {
  after: "inject-objects",
  initialize(owner) {
    let lastAuthResult;

    if (document.getElementById("data-authentication")) {
      // Happens for full screen logins
      lastAuthResult = document.getElementById("data-authentication").dataset
        .authenticationData;
    }

    if (lastAuthResult) {
      const router = owner.lookup("service:router");
      router.one("routeDidChange", () => {
        next(() => {
          const options = JSON.parse(lastAuthResult);

          if (!beforeAuthCompleteCallbacks.every((fn) => fn(options))) {
            return;
          }

          if (router.currentRouteName === "invites.show") {
            owner
              .lookup("controller:invites-show")
              .authenticationComplete(options);
          } else {
            const modal = owner.lookup("service:modal");
            const siteSettings = owner.lookup("service:site-settings");

            const loginError = (errorMsg, className, properties, callback) => {
              const applicationRoute = owner.lookup("route:application");
              const applicationController = owner.lookup(
                "controller:application"
              );

              const loginProps = {
                canSignUp: applicationController.canSignUp,
                flash: errorMsg,
                flashType: className || "success",
                awaitingApproval: options.awaiting_approval,
                ...properties,
              };

              if (siteSettings.experimental_full_page_login) {
                router.transitionTo("login").then((login) => {
                  Object.keys(loginProps || {}).forEach((key) => {
                    login.controller.set(key, loginProps[key]);
                  });
                });
              } else {
                modal.show(LoginModal, {
                  model: {
                    showNotActivated: (props) =>
                      applicationRoute.send("showNotActivated", props),
                    showCreateAccount: (props) =>
                      applicationRoute.send("showCreateAccount", props),
                    ...loginProps,
                  },
                });
              }
              next(() => callback?.());
            };

            if (options.omniauth_disallow_totp) {
              return loginError(
                I18n.t("login.omniauth_disallow_totp"),
                "error",
                {
                  loginName: options.email,
                  showLoginButtons: false,
                },
                () => document.getElementById("login-account-password").focus()
              );
            }

            for (let i = 0; i < AuthErrors.length; i++) {
              const cond = AuthErrors[i];
              if (options[cond]) {
                return loginError(htmlSafe(I18n.t(`login.${cond}`)));
              }
            }

            if (options.suspended) {
              return loginError(options.suspended_message, "error");
            }

            // Reload the page if we're authenticated
            if (options.authenticated) {
              const destinationUrl =
                cookie("destination_url") || options.destination_url;
              if (destinationUrl) {
                // redirect client to the original URL
                removeCookie("destination_url");
                window.location.href = destinationUrl;
              } else if (
                window.location.pathname === DiscourseUrl.getURL("/login")
              ) {
                window.location = DiscourseUrl.getURL("/");
              } else {
                window.location.reload();
              }
              return;
            }

            next(() => {
              const createAccountProps = {
                accountEmail: options.email,
                accountUsername: options.username,
                accountName: options.name,
                authOptions: EmberObject.create(options),
                skipConfirmation: siteSettings.auth_skip_create_confirm,
              };

              if (siteSettings.experimental_full_page_login) {
                router.transitionTo("signup").then((login) => {
                  Object.keys(createAccountProps || {}).forEach((key) => {
                    login.controller.set(key, createAccountProps[key]);
                  });
                });
              } else {
                modal.show(CreateAccount, { model: createAccountProps });
              }
            });
          }
        });
      });
    }
  },
};
