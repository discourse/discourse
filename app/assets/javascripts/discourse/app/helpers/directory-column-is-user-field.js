export default function directoryColumnIsUserField(args) {
  // Args should include key/values { column }
  return args.column.type === "user_field";
}
