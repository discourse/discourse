// Todo: 100% safe transformation from module name to federated export name
export function federatedExportNameFor(moduleName, exportedName) {
  return (
    moduleName.replaceAll("/", "$").replaceAll("-", "__") + "$$" + exportedName
  );
}
