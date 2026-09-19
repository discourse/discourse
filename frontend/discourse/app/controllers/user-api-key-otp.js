import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";

export default class UserApiKeyOtpController extends Controller {
  @tracked error;
  @tracked isLoading = false;
  queryParams = ["application_name", "public_key", "auth_redirect", "padding"];

  get payloadParameters() {
    const data = {
      application_name: this.model.application_name,
      public_key: this.model.public_key,
      auth_redirect: this.model.auth_redirect,
    };

    if (this.model.padding) {
      data.padding = this.model.padding;
    }

    return data;
  }

  @action
  async authorize(event) {
    event?.preventDefault();
    this.isLoading = true;
    this.error = null;

    try {
      const response = await ajax("/user-api-key/otp.json", {
        type: "POST",
        data: this.payloadParameters,
      });
      DiscourseURL.routeTo(response.redirect_url);
    } catch (errorResponse) {
      this.error = extractError(errorResponse);
    } finally {
      this.isLoading = false;
    }
  }
}
