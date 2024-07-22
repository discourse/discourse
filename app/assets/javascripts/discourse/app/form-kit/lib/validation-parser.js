export default class ValidationParser {
  static parse(input) {
    return new ValidationParser().parse(input);
  }

  parse(input) {
    const rules = {};
    (input?.split("|") ?? []).forEach((rule) => {
      const [ruleName, args] = rule.split(":").filter(Boolean);

      if (this[ruleName + "Rule"]) {
        rules[ruleName] = this[ruleName + "Rule"](args);
      } else {
        rules[ruleName] = {};
      }
    });

    return rules;
  }

  requiredRule(args = "") {
    const [option] = args.split(",");
    return {
      trim: option === "trim",
    };
  }

  betweenRule(args) {
    if (!args) {
      throw new Error("`between` rule expects min/max, eg: between:1,10");
    }

    const [min, max] = args.split(",").map(Number);

    return {
      min,
      max,
    };
  }

  lengthRule(args) {
    if (!args) {
      throw new Error("`length` rule expects min/max, eg: length:1,10");
    }

    const [min, max] = args.split(",").map(Number);

    return {
      min,
      max,
    };
  }
}
