import { buildRawConnectorCache } from "discourse-common/lib/raw-templates";
import deprecated from "discourse-common/lib/deprecated";
import DiscourseTemplateMap from "discourse-common/lib/discourse-template-map";
import {
  getComponentTemplate,
  hasInternalComponentManager,
  setComponentTemplate,
} from "@glimmer/manager";
import templateOnly from "@ember/component/template-only";

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

  return foundClass;
}

/**
 * Sets component template, ignoring errors if it's already set to the same template
 */
function safeSetComponentTemplate(template, component) {
  try {
    setComponentTemplate(template, component);
  } catch (e) {
    if (getComponentTemplate(component) !== template) {
      throw e;
    }
  }
}

/**
 * Clear the cache of connectors. Should only be used in tests when
 * `requirejs.entries` is changed.
 */
export function expireConnectorCache() {
  _connectorCache = null;
}

class ConnectorInfo {
  #componentClass;
  #templateOnly;

  constructor(outletName, connectorName, connectorClass, template) {
    this.outletName = outletName;
    this.connectorName = connectorName;
    this.connectorClass = connectorClass;
    this.template = template;
  }

  get componentClass() {
    return (this.#componentClass ??= this.#buildComponentClass());
  }

  get templateOnly() {
    return (this.#templateOnly ??= this.#buildTemplateOnlyClass());
  }

  get classicClassNames() {
    return `${this.outletName}-outlet ${this.connectorName}`;
  }

  #buildComponentClass() {
    const klass = this.connectorClass;
    if (klass && hasInternalComponentManager(klass)) {
      safeSetComponentTemplate(this.template, klass);
      this.#warnUnusableHooks();
      return klass;
    } else {
      return false;
    }
  }

  #buildTemplateOnlyClass() {
    const component = templateOnly();
    setComponentTemplate(this.template, component);
    this.#warnUnusableHooks();
    return component;
  }

  #warnUnusableHooks() {
    for (const methodName of [
      "actions",
      "setupComponent",
      "teardownComponent",
    ]) {
      if (this.connectorClass?.[methodName]) {
        deprecated(
          `actions, setupComponent and teardownComponent hooks cannot be used with Glimmer plugin outlets. Define a component class instead. (${this.outletName}/${this.connectorName}).`,
          { id: "discourse.plugin-outlet-classic-hooks" }
        );
      }
    }
  }
}

function buildConnectorCache() {
  _connectorCache = {};

  findOutlets(
    DiscourseTemplateMap.keys(),
    (outletName, resource, connectorName) => {
      _connectorCache[outletName] ||= [];

      const template = require(DiscourseTemplateMap.resolve(resource)).default;
      const connectorClass = findClass(outletName, connectorName);

      _connectorCache[outletName].push(
        new ConnectorInfo(outletName, connectorName, connectorClass, template)
      );
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
    const shouldRender = con.connectorClass?.shouldRender;
    return !shouldRender || shouldRender(args, context);
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
