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
      }
    });

    return rules;
  }

  requiredRule() {
    return true;
  }

  betweenRule(args) {
    const [min, max] = args.split(",").map(Number);

    return {
      min,
      max,
    };
  }

  lengthRule(args) {
    const [min, max] = args.split(",").map(Number);

    return {
      min,
      max,
    };
  }
}
