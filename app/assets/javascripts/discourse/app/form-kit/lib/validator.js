import { isBlank } from "@ember/utils";
import I18n from "discourse-i18n";

export default class Validator {
  constructor(value, rules = {}) {
    this.value = value;
    this.rules = rules;
  }

  async validate(type) {
    const errors = [];
    for (const rule in this.rules) {
      if (this[rule + "Validator"]) {
        const error = await this[rule + "Validator"](
          this.value,
          this.rules[rule],
          type
        );

        if (error) {
          errors.push(error);
        }
      } else {
        throw new Error(`Unknown validator: ${rule}`);
      }
    }

    return errors;
  }

  integerValidator(value) {
    if (!Number.isInteger(Number(value))) {
      return I18n.t("form_kit.errors.not_an_integer");
    }
  }

  lengthValidator(value, rule) {
    if (rule.max) {
      if (value?.length > rule.max) {
        return I18n.t("form_kit.errors.too_long", {
          count: rule.max,
        });
      }
    }

    if (rule.min) {
      if (value?.length < rule.min) {
        return I18n.t("form_kit.errors.too_short", {
          count: rule.min,
        });
      }
    }
  }

  betweenValidator(value, rule) {
    if (rule.max) {
      if (value > rule.max) {
        return I18n.t("form_kit.errors.too_high", {
          count: rule.max,
        });
      }
    }

    if (rule.min) {
      if (value < rule.min) {
        return I18n.t("form_kit.errors.too_low", {
          count: rule.min,
        });
      }
    }
  }

  numberValidator(value) {
    if (isNaN(Number(value))) {
      return I18n.t("form_kit.errors.not_a_number");
    }
  }

  acceptedValidator(value) {
    const acceptedValues = ["yes", "on", true, 1, "true"];
    if (!acceptedValues.includes(value)) {
      return I18n.t("form_kit.errors.not_accepted");
    }
  }

  urlValidator(value) {
    try {
      // eslint-disable-next-line no-new
      new URL(value);
    } catch {
      return I18n.t("form_kit.errors.invalid_url");
    }
  }

  requiredValidator(value, rule, type) {
    let error = false;

    switch (type) {
      case "input-text":
        if (rule.trim) {
          value = value?.trim();
        }
        if (!value || value === "") {
          error = true;
        }
        break;
      case "input-number":
        if ((!value && value !== 0) || isNaN(Number(value))) {
          error = true;
        }
        break;
      case "question":
        if (value !== false && !value) {
          error = true;
        }
        break;
      default:
        if (isBlank(value)) {
          error = true;
        }
    }

    if (error) {
      return I18n.t("form_kit.errors.required");
    }
  }
}
