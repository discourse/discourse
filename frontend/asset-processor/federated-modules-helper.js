export function federatedExportNameFor(moduleName, exportedName) {
  if (exportedName === "*") {
    exportedName = "__module";
  }
  return (
    moduleName.replaceAll("/", "$").replaceAll("-", "__") + "$$" + exportedName
  );
}
