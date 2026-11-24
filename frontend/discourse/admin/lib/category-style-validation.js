import categoryStyleType from "discourse/lib/category-style-type";
import { isValidHex } from "discourse/lib/color-transformations";
import { i18n } from "discourse-i18n";

export function categoryColorError(color) {
  if (!color) {
    return i18n("category.color_validations.cant_be_empty");
  }
  if (!isValidHex(color)) {
    return [3, 6].includes(color.length)
      ? i18n("category.color_validations.non_hexdecimal")
      : i18n("category.color_validations.incorrect_length");
  }
}

export function categoryStyleErrors(data) {
  const errors = [];
  const style = categoryStyleType(data.style_type);
  if (["emoji", "icon"].includes(style) && !data[style]) {
    errors.push({
      title: i18n(`category.styles.${style}`),
      message: i18n(`category.validations.${style}_required`),
    });
  }

  const message = categoryColorError(data.color);
  if (message) {
    errors.push({ title: i18n("category.background_color"), message });
  }
  return errors;
}
