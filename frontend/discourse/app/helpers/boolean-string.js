export default function booleanString(value, opts = { omitFalse: true }) {
  if (opts.omitFalse && !value) {
    return;
  }

  return value ? "true" : "false";
}
