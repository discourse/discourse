export default class ValidationParser {
  static parse(input) {
    return new ValidationParser().parse(input);
  }

  parse(input) {
    const rules = {};
    (input?.split("|") ?? []).forEach((rule) => {
      const firstColonIndex = rule.indexOf(":");
      const ruleName = rule.substring(
        0,
        firstColonIndex !== -1 ? firstColonIndex : rule.length
      );
      const args =
        firstColonIndex !== -1 ? rule.substring(firstColonIndex + 1) : "";

      if (this[ruleName + "Rule"]) {
        rules[ruleName] = this[ruleName + "Rule"](args);
      } else {
        rules[ruleName] = {};
      }
    });

    return rules;
  }

  dateBeforeOrEqualRule(input) {
    return {
      date: moment(input).toDate(),
      day: moment(input).format("YYYY-MM-DD"),
      time: moment(input).format("HH:mm"),
    };
  }

  dateAfterOrEqualRule(input) {
    return {
      date: moment(input).toDate(),
      day: moment(input).format("YYYY-MM-DD"),
      time: moment(input).format("HH:mm"),
    };
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
