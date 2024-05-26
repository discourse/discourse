import { z } from "zod";

export default class Validator {
  static async validate(value, rules = {}) {
    return await new Validator().validate(value, rules);
  }

  async validate(value, rules = {}) {
    console.log("value", value, rules);
    let schema;
    if (rules.between) {
      schema = z.coerce.number();
    } else {
      schema = z.string();
    }

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
    // return schema.required();
    return schema;
  }
}
