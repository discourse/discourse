import { assert } from "@ember/debug";
import { z } from "zod";

const SUPPORTED_PRIMITIVES = ["string", "number", "boolean"];

export default class Validator {
  static async validate(value, type, rules = {}) {
    return await new Validator().validate(value, type, rules);
  }

  async validate(value, type, rules = {}) {
    assert(
      `Type must be one of ${SUPPORTED_PRIMITIVES.join(", ")}`,
      SUPPORTED_PRIMITIVES.includes(type)
    );

    let schema = z[type]();

    Object.keys(rules).forEach((rule) => {
      if (this[rule + "Validator"]) {
        schema = this[rule + "Validator"](schema, rules[rule]);
      } else {
        console.warn(`Unknown validator: ${rule}`);
      }
    });

    const parse = schema.safeParse(value);

    if (!parse.success) {
      return parse.error?.formErrors?.formErrors ?? [];
    }
  }

  lengthValidator(schema, rule) {
    if (rule.max) {
      schema = schema.max(rule.max);
    }
    if (rule.min) {
      schema = schema.min(rule.min);
    }

    return schema;
  }

  betweenValidator(schema, rule) {
    if (rule.max) {
      schema = schema.lte(rule.max);
    }
    if (rule.min) {
      schema = schema.gte(rule.min);
    }

    return schema;
  }

  requiredValidator(schema, rule) {
    if (schema instanceof z.ZodString) {
      if (rule.trim) {
        schema = schema.trim();
      }

      schema = schema.min(1, "Required");
    }

    return schema;
  }

  requiredPreprocessor(schema, rule) {
    schema = z.preprocess((val) => {
      if (rule.trim) {
        val = val.trim();
      }

      console.log("trimmed", val === "" ? null : val);

      return val === "" ? null : val;
    }, schema);

    return schema;
  }
}
