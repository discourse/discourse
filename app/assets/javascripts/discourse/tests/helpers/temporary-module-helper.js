import DiscourseTemplateMap from "discourse/lib/discourse-template-map";
import { expireConnectorCache } from "discourse/lib/plugin-connectors";
import { expireModuleTrieCache } from "discourse-common/resolver";

const modifications = [];

function generateTemporaryModule(defaultExport) {
  return function (_exports) {
    Object.defineProperty(_exports, "__esModule", {
      value: true,
    });
    _exports.default = defaultExport;
  };
}

export function registerTemporaryModule(moduleName, defaultExport) {
  const modificationData = {
    moduleName,
    existingModule: requirejs.entries[moduleName],
  };
  delete requirejs.entries[moduleName];
  define(moduleName, ["exports"], generateTemporaryModule(defaultExport));
  modifications.push(modificationData);
  expireConnectorCache();
  expireModuleTrieCache();
  DiscourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
}

export function cleanupTemporaryModuleRegistrations() {
  for (const modificationData of modifications.reverse()) {
    const { moduleName, existingModule } = modificationData;
    delete requirejs.entries[moduleName];
    if (existingModule) {
      requirejs.entries[moduleName] = existingModule;
    }
  }
  if (modifications.length) {
    expireConnectorCache();
    DiscourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
  }
  modifications.clear();
}
