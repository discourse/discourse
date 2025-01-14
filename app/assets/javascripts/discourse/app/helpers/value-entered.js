import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("value-entered", valueEntered);
export default function valueEntered(value) {
  if (!value) {
    return "";
  } else if (value.length > 0) {
    return "value-entered";
  } else {
    return "";
  }
}
