import { z } from "zod";

export default class Validator {
  static async validate(node) {
    return await new Validator().validate(node);
  }

  async validate(node) {
    let schema;
    if (node.rules.between) {
      schema = z.coerce.number();
    } else {
      schema = z.string();
    }

    Object.keys(node.rules).forEach((rule) => {
      if (this[rule + "Validator"]) {
        schema = this[rule + "Validator"](schema, node.rules[rule]);
      } else {
        console.warn(`Unknown validator: ${rule}`);
      }
    });

    const parse = schema.safeParse(node.config.value);

    node.valid = parse.success;
    node.validationMessages = parse.error?.formErrors?.formErrors ?? [];
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
