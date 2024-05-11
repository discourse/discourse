import { z } from "zod";

export default class Validator {
  async validate(node) {
    const mySchema = z
      .string({
        required_error: "Name is required",
      })
      .length(5, { message: "Value must be 5 characters long" });

    // "safe" parsing (doesn't throw error if validation fails)
    const parse = mySchema.safeParse(node.config.value);

    console.log(parse);
    node.valid = parse.success;
    node.validationMessages = parse.error?.formErrors?.formErrors ?? [];
  }
}
