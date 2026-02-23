// Todo: 100% safe transformation from module name to federated export name
export function federatedExportNameFor(moduleName, exportedName) {
  if (exportedName === "*") {
    exportedName = "__module";
  }
  return (
    moduleName.replaceAll("/", "$").replaceAll("-", "__") + "$$" + exportedName
  );
}
