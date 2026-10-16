import { i18n } from "discourse-i18n";
import { isEmptyExpression, isExpression } from "./property-engine.js";

const CRON_FIELD_PATTERN =
  /^(\*|\d+(-\d+)?(\/\d+)?|\*\/\d+)(,(\*|\d+(-\d+)?(\/\d+)?|\*\/\d+))*$/;

function isValidCron(value) {
  if (!value || typeof value !== "string") {
    return false;
  }
  const fields = value.trim().split(/\s+/);
  return fields.length === 5 && fields.every((f) => CRON_FIELD_PATTERN.test(f));
}

const FIELD_VALIDATORS = {
  cron: (name, value, { addError }) => {
    if (value && !isExpression(value) && !isValidCron(value)) {
      addError(name, {
        title: i18n("discourse_workflows.schedule.cron"),
        message: i18n("discourse_workflows.schedule.cron_invalid"),
      });
    }
  },
  // A blank expression runs as an empty string, which is never what was meant.
  non_empty_expression: (name, value, { addError, title }) => {
    if (isEmptyExpression(value)) {
      addError(name, {
        title,
        message: i18n("discourse_workflows.parameter_field.empty_expression", {
          plain: i18n("discourse_workflows.parameter_field.plain"),
        }),
      });
    }
  },
};

/**
 * Returns the FormKit `@validate` callback named by `schema.validate`.
 *
 * @param {object} schema - The field schema.
 * @param {string} title - The field title shown with any error.
 * @returns {Function|undefined}
 */
export function fieldValidator(schema, title) {
  const validator = FIELD_VALIDATORS[schema?.validate];
  if (!validator) {
    return undefined;
  }

  return (name, value, helpers) =>
    validator(name, value, { ...helpers, title });
}
