import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { longDate } from "discourse/lib/formatter";
import DiscourseURL from "discourse/lib/url";
import { USER_API_KEY_AUTHORIZATION_STATES } from "discourse/lib/user-api-key-device-auth";
import { clipboardCopy } from "discourse/lib/utilities";

export default class UserApiKeyNewController extends Controller {
  @tracked page;
  @tracked result;
  @tracked error;
  @tracked isLoading = false;
  @tracked copied = false;
  queryParams = [
    "nonce",
    "scopes",
    "client_id",
    "application_name",
    "public_key",
    "auth_redirect",
    "push_url",
    "padding",
    "expires_in_seconds",
  ];

  reset(model) {
    this.page = model;
    this.result = null;
    this.error = null;
    this.isLoading = false;
    this.copied = false;
  }

  get ready() {
    return this.page?.state === USER_API_KEY_AUTHORIZATION_STATES.READY;
  }

  get noTrustLevel() {
    return (
      this.page?.state === USER_API_KEY_AUTHORIZATION_STATES.NO_TRUST_LEVEL
    );
  }

  get genericError() {
    return this.page?.state === USER_API_KEY_AUTHORIZATION_STATES.GENERIC_ERROR;
  }

  get avatarUrl() {
    return this.page?.current_user?.avatar_template?.replace("{size}", "24");
  }

  get expiresAt() {
    return this.page?.expires_at ? longDate(this.page.expires_at) : null;
  }

  get copyButtonLabel() {
    return this.copied ? "user_api_key.copied" : "user_api_key.copy_key";
  }

  get payloadParameters() {
    const data = {
      application_name: this.page.application_name,
      nonce: this.page.nonce,
      client_id: this.page.client_id,
      push_url: this.page.push_url,
      public_key: this.page.public_key,
      scopes: this.page.scopes,
    };

    if (this.page.auth_redirect) {
      data.auth_redirect = this.page.auth_redirect;
    }
    if (this.page.padding) {
      data.padding = this.page.padding;
    }
    if (this.page.expires_in_seconds) {
      data.expires_in_seconds = this.page.expires_in_seconds;
    }

    return data;
  }

  @action
  async copy() {
    try {
      await clipboardCopy(this.result.payload?.replace(/\s/g, ""));
      this.copied = true;
    } catch {
      this.copied = false;
    }

    if (this.copied) {
      setTimeout(() => (this.copied = false), 2000);
    }
  }

  @action
  async authorize(event) {
    event?.preventDefault();
    this.isLoading = true;
    this.error = null;

    try {
      const response = await ajax("/user-api-key.json", {
        type: "POST",
        data: this.payloadParameters,
      });

      if (response.redirect_url) {
        DiscourseURL.routeTo(response.redirect_url);
      } else {
        this.result = response;
      }
    } catch (errorResponse) {
      this.error = extractError(errorResponse);
    } finally {
      this.isLoading = false;
    }
  }
}
