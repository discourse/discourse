export default function valueEntered(value) {
  if (!value) {
    return "";
  } else if (value.length > 0) {
    return "value-entered";
  } else {
    return "";
  }
}
