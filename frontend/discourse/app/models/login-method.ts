import EmberObject, { computed } from "@ember/object";
import { Promise } from "rsvp";
import { updateCsrfToken } from "discourse/lib/ajax";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import Session from "discourse/models/session";
import Site, { type SiteAuthProvider } from "discourse/models/site";
import { i18n } from "discourse-i18n";

/** Provider payload plus optional client hooks and cached display flags. */
export interface LoginMethodFields extends SiteAuthProvider {
  /** Optional login hook; no production writer is currently known. */
  customLogin?: () => void;
  isGoogle?: boolean;
  isDiscourseID?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface LoginMethod extends LoginMethodFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class LoginMethod extends EmberObject {
  static buildPostForm(
    url: string,
    params: Record<string, unknown> = {}
  ): globalThis.Promise<HTMLFormElement> {
    // Login always happens in an anonymous context, with no CSRF token
    // So we need to fetch it before sending a POST request
    return updateCsrfToken().then(() => {
      const form = document.createElement("form");
      form.setAttribute("style", "display:none;");
      form.setAttribute("method", "post");
      form.setAttribute("action", url);

      const csrfInput = document.createElement("input");
      csrfInput.setAttribute("name", "authenticity_token");
      // setAttribute coerces nullish tokens just as it does other form values.
      csrfInput.setAttribute(
        "value",
        Session.currentProp("csrfToken") as string
      );
      form.appendChild(csrfInput);

      Object.keys(params).forEach((key) => {
        const input = document.createElement("input");
        input.setAttribute("name", key);
        // Preserve the DOM's coercion of arbitrary authentication parameters.
        input.setAttribute("value", params[key] as string);
        form.appendChild(input);
      });

      document.body.appendChild(form);

      return form;
    });
  }

  @computed
  get title(): string {
    return this.title_override || i18n(`login.${this.name}.title`);
  }

  @computed
  get icon(): string {
    return this.icon_override || "user";
  }

  @computed
  get screenReaderTitle(): string {
    return (
      this.title_override ||
      i18n(`login.${this.name}.sr_title`, { defaultValue: this.title })
    );
  }

  @computed
  get prettyName(): string {
    return this.pretty_name_override || i18n(`login.${this.name}.name`);
  }

  /** Adds login flags, email and origin to the caller's params object in place. */
  doLogin({
    reconnect = false,
    signup = false,
    params = {},
  }: {
    reconnect?: boolean;
    signup?: boolean;
    params?: Record<string, unknown>;
  } = {}): globalThis.Promise<void> {
    if (this.customLogin) {
      this.customLogin();
      return Promise.resolve();
    }

    if (this.custom_url) {
      // Window's setter accepts a URL string; the global intersection obscures it.
      (window as Window).location = this.custom_url;
      return Promise.resolve();
    }

    if (reconnect) {
      params.reconnect = true;
    }

    if (signup) {
      params.signup = true;

      const email = Session.currentProp("email");
      if (email) {
        params.email = email;
      }
    }

    const destinationUrl = cookie("destination_url");
    if (destinationUrl) {
      params.origin = destinationUrl;
    }

    return LoginMethod.buildPostForm(getURL(`/auth/${this.name}`), params).then(
      (form) => form.submit()
    );
  }
}

let methods: LoginMethod[] | undefined;

export function findAll(): LoginMethod[] {
  if (methods) {
    return methods;
  }

  methods = Site.currentProp("auth_providers").map((provider) =>
    LoginMethod.create(provider)
  );

  // exclude FA icon for Google, uses custom SVG
  methods.forEach((m) => m.set("isGoogle", m.name === "google_oauth2"));

  methods.forEach((m) => m.set("isDiscourseID", m.name === "discourse_id"));

  return methods;
}

export function clearAuthMethods(): void {
  methods = undefined;
}
