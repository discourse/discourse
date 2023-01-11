import { buildRawConnectorCache } from "discourse-common/lib/raw-templates";
import deprecated from "discourse-common/lib/deprecated";
import DiscourseTemplateMap from "discourse-common/lib/discourse-template-map";

let _connectorCache;
let _rawConnectorCache;
let _extraConnectorClasses = {};
let _classPaths;

export function resetExtraClasses() {
  _extraConnectorClasses = {};
  _classPaths = undefined;
}

// Note: In plugins, define a class by path and it will be wired up automatically
// eg: discourse/connectors/<OUTLET NAME>/<CONNECTOR NAME>
export function extraConnectorClass(name, obj) {
  _extraConnectorClasses[name] = obj;
}

const DefaultConnectorClass = {
  actions: {},
  shouldRender: () => true,
  setupComponent() {},
  teardownComponent() {},
};

function findOutlets(keys, callback) {
  keys.forEach(function (res) {
    const segments = res.split("/");
    if (segments.includes("connectors")) {
      const outletName = segments[segments.length - 2];
      const uniqueName = segments[segments.length - 1];

      callback(outletName, res, uniqueName);
    }
  });
}

export function clearCache() {
  _connectorCache = null;
  _rawConnectorCache = null;
}

function findClass(outletName, uniqueName) {
  if (!_classPaths) {
    _classPaths = {};
    findOutlets(Object.keys(require._eak_seen), (outlet, res, un) => {
      const possibleConnectorClass = requirejs(res).default;
      if (possibleConnectorClass.__id) {
        // This is the template, not the connector class
        return;
      }
      _classPaths[`${outlet}/${un}`] = possibleConnectorClass;
    });
  }

  const id = `${outletName}/${uniqueName}`;
  let foundClass = _extraConnectorClasses[id] || _classPaths[id];

  return foundClass
    ? Object.assign({}, DefaultConnectorClass, foundClass)
    : DefaultConnectorClass;
}

/**
 * Clear the cache of connectors. Should only be used in tests when
 * `requirejs.entries` is changed.
 */
export function expireConnectorCache() {
  _connectorCache = null;
}

function buildConnectorCache() {
  _connectorCache = {};

  findOutlets(
    DiscourseTemplateMap.keys(),
    (outletName, resource, uniqueName) => {
      _connectorCache[outletName] = _connectorCache[outletName] || [];

      _connectorCache[outletName].push({
        outletName,
        templateName: resource,
        template: require(DiscourseTemplateMap.resolve(resource)).default,
        classNames: `${outletName}-outlet ${uniqueName}`,
        connectorClass: findClass(outletName, uniqueName),
      });
    }
  );
}

export function connectorsFor(outletName) {
  if (!_connectorCache) {
    buildConnectorCache();
  }
  return _connectorCache[outletName] || [];
}

export function renderedConnectorsFor(outletName, args, context) {
  return connectorsFor(outletName).filter((con) => {
    return con.connectorClass.shouldRender(args, context);
  });
}

export function rawConnectorsFor(outletName) {
  if (!_rawConnectorCache) {
    _rawConnectorCache = buildRawConnectorCache(findOutlets);
  }
  return _rawConnectorCache[outletName] || [];
}

export function buildArgsWithDeprecations(args, deprecatedArgs) {
  const output = {};

  Object.keys(args).forEach((key) => {
    Object.defineProperty(output, key, { value: args[key] });
  });

  Object.keys(deprecatedArgs).forEach((key) => {
    Object.defineProperty(output, key, {
      get() {
        deprecated(`${key} is deprecated`, {
          id: "discourse.plugin-connector.deprecated-arg",
        });

        return deprecatedArgs[key];
      },
    });
  });

  return output;
}
