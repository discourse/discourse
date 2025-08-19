import { isBlank } from "@ember/utils";
import moment from "moment";
import { i18n } from "discourse-i18n";

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

  dateBeforeOrEqualValidator(value, rule) {
    if (!moment(value).isSameOrBefore(rule.date, "day")) {
      return i18n("form_kit.errors.date_before_or_equal", {
        date: moment(rule.date).format("LL"),
      });
    }
  }

  dateAfterOrEqualValidator(value, rule) {
    if (!moment(value).isSameOrAfter(rule.date, "day")) {
      return i18n("form_kit.errors.date_after_or_equal", {
        date: moment(rule.date).format("LL"),
      });
    }
  }

  integerValidator(value) {
    if (!Number.isInteger(Number(value))) {
      return i18n("form_kit.errors.not_an_integer");
    }
  }

  lengthValidator(value, rule) {
    if (isBlank(value)) {
      return;
    }

    if (rule.max) {
      if (value?.length > rule.max) {
        return i18n("form_kit.errors.too_long", {
          count: rule.max,
        });
      }
    }

    if (rule.min) {
      if (value?.length < rule.min) {
        return i18n("form_kit.errors.too_short", {
          count: rule.min,
        });
      }
    }
  }

  betweenValidator(value, rule) {
    if (rule.max) {
      if (value > rule.max) {
        return i18n("form_kit.errors.too_high", {
          count: rule.max,
        });
      }
    }

    if (rule.min) {
      if (value < rule.min) {
        return i18n("form_kit.errors.too_low", {
          count: rule.min,
        });
      }
    }
  }

  numberValidator(value) {
    if (isNaN(Number(value))) {
      return i18n("form_kit.errors.not_a_number");
    }
  }

  acceptedValidator(value) {
    const acceptedValues = ["yes", "on", true, 1, "true"];
    if (!acceptedValues.includes(value)) {
      return i18n("form_kit.errors.not_accepted");
    }
  }

  urlValidator(value) {
    try {
      // eslint-disable-next-line no-new
      new URL(value);
    } catch {
      return i18n("form_kit.errors.invalid_url");
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
      return i18n("form_kit.errors.required");
    }
  }

  startsWithValidator(value, rule, type) {
    let error = false;

    if (isBlank(value)) {
      return;
    }

    switch (type) {
      case "input":
      case "input-text":
      case "text":
        if (!value.startsWith(rule.prefix)) {
          error = true;
        }
        break;
    }

    if (error) {
      return i18n("form_kit.errors.starts_with", {
        prefix: rule.prefix,
      });
    }
  }

  endsWithValidator(value, rule, type) {
    let error = false;

    if (isBlank(value)) {
      return;
    }

    switch (type) {
      case "input":
      case "input-text":
      case "text":
        if (!value.endsWith(rule.suffix)) {
          error = true;
        }
        break;
    }

    if (error) {
      return i18n("form_kit.errors.ends_with", {
        suffix: rule.suffix,
      });
    }
  }
}
