import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { longDate } from "discourse/lib/formatter";
import { USER_API_KEY_DEVICE_ACTIVATION_STATES } from "discourse/lib/user-api-key-device-auth";
import { i18n } from "discourse-i18n";

const CODE_FIELD = "code";

export default class UserApiKeyActivateController extends Controller {
  @tracked page;
  @tracked error = null;
  @tracked isLoading = false;
  queryParams = ["request"];
  request = null;
  codeFormApi = null;
  codeFormData = { [CODE_FIELD]: "" };
  approvalFormData = {};

  normalizeCode(value) {
    return value?.toUpperCase().replace(/[^A-Z0-9]/g, "") || "";
  }

  reset(model) {
    this.page = model;
    this.error = null;
    this.isLoading = false;
    this.codeFormApi = null;
  }

  get showEnterCode() {
    return (
      this.page?.state === USER_API_KEY_DEVICE_ACTIVATION_STATES.ENTER_CODE
    );
  }

  get showAuthorize() {
    return this.page?.state === USER_API_KEY_DEVICE_ACTIVATION_STATES.AUTHORIZE;
  }

  get showComplete() {
    return this.page?.state === USER_API_KEY_DEVICE_ACTIVATION_STATES.COMPLETE;
  }

  get deviceExpiresAt() {
    const expiresAt = this.page?.device_auth?.expires_at;
    return expiresAt ? longDate(expiresAt) : null;
  }

  get avatarUrl() {
    return this.page?.current_user?.avatar_template?.replace("{size}", "24");
  }

  @action
  registerCodeFormApi(api) {
    this.codeFormApi = api;
  }

  @action
  validateCode(name, value, { addError }) {
    if (this.normalizeCode(value).length !== 8) {
      addError(name, {
        title: i18n("user_api_key.device.code"),
        message: i18n("user_api_key.device.enter_full_code"),
      });
    }
  }

  addCodeError(message) {
    this.codeFormApi?.addError(CODE_FIELD, {
      title: i18n("user_api_key.device.code"),
      message,
    });
  }

  showInvalidCodeError() {
    this.addCodeError(i18n("user_api_key.device.invalid_code"));
  }

  @action
  async submitCode(data) {
    this.isLoading = true;
    this.error = null;

    try {
      this.page = await ajax("/user-api-key/activate.json", {
        type: "POST",
        data: { code: this.normalizeCode(data.code) },
      });

      if (this.page.invalid_code) {
        this.showInvalidCodeError();
      }
    } catch (errorResponse) {
      this.error = extractError(errorResponse);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async approve(data) {
    await this.submitAuthorization(
      "/user-api-key/device/authorize.json",
      data?.code
    );
  }

  @action
  async approveWithApprovalToken() {
    await this.submitAuthorization("/user-api-key/device/authorize.json");
  }

  @action
  async deny(event) {
    event?.preventDefault();
    await this.submitAuthorization("/user-api-key/device/deny.json");
  }

  async submitAuthorization(url, code) {
    this.isLoading = true;
    this.error = null;

    const data = this.page.request_token
      ? {
          request: this.page.request_token,
          code: this.normalizeCode(code),
        }
      : { approval_token: this.page.approval_token };

    try {
      this.page = await ajax(url, { type: "POST", data });

      if (this.page.invalid_code) {
        this.showInvalidCodeError();
      }
    } catch (errorResponse) {
      this.error = extractError(errorResponse);
    } finally {
      this.isLoading = false;
    }
  }
}
