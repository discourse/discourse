import { assert, warn } from "@ember/debug";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

const SUPPORTED_PRIMITIVES = ["string", "number", "boolean"];

export default class Validator {
  constructor(value, rules = {}) {
    this.value = value;
    this.rules = rules;
    this.errors = [];
  }

  @bind
  addError(error) {
    this.errors.push(error);
  }

  async validate() {
    for (const rule in this.rules) {
      if (this[rule + "Validator"]) {
        await this[rule + "Validator"](this.value, this.rules[rule]);
      } else {
        warn(`Unknown validator: ${rule}`);
      }
    }

    return this.errors;
  }

  lengthValidator(value, rule) {
    if (rule.max) {
      if (value?.length > rule.max) {
        this.errors.push({
          type: "too_long",
          value,
          message: I18n.t("form_kit.errors.too_long", {
            count: rule.max,
          }),
        });
      }
    }

    if (rule.min) {
      if (value?.length < rule.min) {
        this.errors.push({
          type: "too_short",
          value,
          message: I18n.t("form_kit.errors.too_short", {
            count: rule.min,
          }),
        });
      }
    }
  }

  betweenValidator(value, rule) {
    if (rule.max) {
      if (value > rule.max) {
        this.errors.push({
          type: "too_high",
          value,
          message: I18n.t("form_kit.errors.too_high", {
            count: rule.max,
          }),
        });
      }
    }

    if (rule.min) {
      if (value < rule.min) {
        this.errors.push({
          type: "too_low",
          value,
          message: I18n.t("form_kit.errors.too_low", {
            count: rule.min,
          }),
        });
      }
    }
  }

  requiredValidator(value, rule) {
    let error = false;

    switch (typeof value) {
      case "string":
        if (rule.trim) {
          value = value?.trim();
        }
        if (!value || value === "") {
          error = true;
        }
        break;
      case "number":
        if (typeof value === "undefined" || isNaN(Number(value))) {
          error = true;
        }
        break;
      case "boolean":
        if (value !== true && value !== false) {
          error = true;
        }
        break;
      default:
        throw new Error("Unsupported field type");
    }

    if (error) {
      this.errors.push({
        type: "required",
        value,
        message: I18n.t("form_kit.errors.required"),
      });
    }
  }
}
