import EmberObject from "@ember/object";
import { next } from "@ember/runloop";
import cookie, { removeCookie } from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const AuthErrors = [
  "admin_not_allowed_from_ip_address",
  "awaiting_activation",
  "awaiting_approval",
  "not_allowed_from_ip_address",
  "requires_invite",
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
    const lastAuthResult = document.getElementById("data-authentication")
      ?.dataset?.authenticationData;

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
              .lookup("controller:invites.show")
              .authenticationComplete(options);
          } else {
            const siteSettings = owner.lookup("service:site-settings");

            const loginError = (flash, properties, callback) => {
              const props = {
                flash,
                flashType: "error",
                awaitingApproval: options.awaiting_approval,
                ...properties,
              };

              router.transitionTo("login").then(() => {
                const controller = owner.lookup("controller:login");
                controller.setProperties(props);
              });

              next(() => callback?.());
            };

            const error = AuthErrors.find((name) => options[name]);
            if (error) {
              return loginError(i18n(`login.${error}`));
            }

            if (options.suspended) {
              return loginError(options.suspended_message);
            }

            if (options.omniauth_disallow_totp) {
              return loginError(
                i18n("login.omniauth_disallow_totp"),
                {
                  loginName: options.email,
                  showLoginButtons: false,
                },
                () => document.getElementById("login-account-password").focus()
              );
            }

            if (options.authenticated) {
              const destinationUrl =
                cookie("destination_url") || options.destination_url;
              if (destinationUrl) {
                removeCookie("destination_url");
                window.location.href = destinationUrl;
              } else if (window.location.pathname === getURL("/login")) {
                window.location = getURL("/");
              } else {
                window.location.reload();
              }
              return;
            }

            next(() => {
              const props = {
                accountEmail: options.email,
                accountUsername: options.username,
                accountName: options.name,
                authOptions: EmberObject.create(options),
                skipConfirmation: siteSettings.auth_skip_create_confirm,
              };

              router.transitionTo("signup").then(() => {
                const controller = owner.lookup("controller:signup");
                controller.setProperties(props);
                controller.handleSkipConfirmation();
              });
            });
          }
        });
      });
    }
  },
};
