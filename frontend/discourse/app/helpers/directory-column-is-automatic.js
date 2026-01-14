export default function directoryColumnIsAutomatic(args) {
  // Args should include key/values { column }
  return args.column.type === "automatic";
}
