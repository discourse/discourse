import { next } from "@ember/runloop";
import cookie, { removeCookie } from "discourse/lib/cookie";
import DiscourseUrl from "discourse/lib/url";
import EmberObject from "@ember/object";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import LoginModal from "discourse/components/modal/login";

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
      const router = owner.lookup("router:main");
      router.one("didTransition", () => {
        next(() => {
          const options = JSON.parse(lastAuthResult);

          if (!beforeAuthCompleteCallbacks.every((fn) => fn(options))) {
            return;
          }

          if (router.currentPath === "invites.show") {
            owner
              .lookup("controller:invites-show")
              .authenticationComplete(options);
          } else {
            const modal = owner.lookup("service:modal");
            const siteSettings = owner.lookup("service:site-settings");

            const loginError = (errorMsg, className, properties, callback) => {
              const applicationRouter = owner.lookup("route:application");
              const applicationController = owner.lookup(
                "controller:application"
              );
              modal.show(LoginModal, {
                model: {
                  showNotActivated: (props) =>
                    applicationRouter.send("showNotActivated", props),
                  showCreateAccount: (props) =>
                    applicationRouter.send("showCreateAccount", props),
                  canSignUp: applicationController.canSignUp,
                  flash: errorMsg,
                  flashType: className || "success",
                  awaitingApproval: options.awaiting_approval,
                  ...properties,
                },
              });
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
                return loginError(I18n.t(`login.${cond}`));
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

            const skipConfirmation = siteSettings.auth_skip_create_confirm;
            owner.lookup("controller:createAccount").setProperties({
              accountEmail: options.email,
              accountUsername: options.username,
              accountName: options.name,
              authOptions: EmberObject.create(options),
              skipConfirmation,
            });

            next(() => {
              showModal("create-account", {
                modalClass: "create-account",
                titleAriaElementId: "create-account-title",
              });
            });
          }
        });
      });
    }
  },
};
