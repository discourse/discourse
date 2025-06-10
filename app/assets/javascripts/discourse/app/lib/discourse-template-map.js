import { isTesting } from "discourse/lib/environment";

const pluginRegex =
  /^discourse\/plugins\/([^\/]+)\/(?:discourse\/templates\/)?(.*)$/;
const themeRegex =
  /^discourse\/theme-([^\/]+)\/(?:discourse\/templates\/)?(.*)$/;

const NAMESPACES = ["discourse/", "admin/"];

function isInRecognisedNamespace(moduleName) {
  for (const ns of NAMESPACES) {
    if (moduleName.startsWith(ns)) {
      return true;
    }
  }
  return false;
}

function isTemplate(moduleName) {
  return moduleName.includes("/templates/");
}

function appendToCache(cache, key, value) {
  let cachedValue = cache.get(key);
  cachedValue ??= [];
  cachedValue.push(value);
  cache.set(key, cachedValue);
}

function buildPrioritizedMaps(moduleNames) {
  const coreTemplates = new Map();
  const pluginTemplates = new Map();
  const themeTemplates = new Map();

  for (const moduleName of moduleNames) {
    if (isInRecognisedNamespace(moduleName) && isTemplate(moduleName)) {
      let pluginMatch, themeMatch;
      if ((pluginMatch = moduleName.match(pluginRegex))) {
        appendToCache(pluginTemplates, pluginMatch[2], moduleName);
      } else if ((themeMatch = moduleName.match(themeRegex))) {
        appendToCache(themeTemplates, themeMatch[2], moduleName);
      } else {
        appendToCache(
          coreTemplates,
          moduleName.replace(/^discourse\/templates\//, ""),
          moduleName
        );
      }
    }
  }

  return [coreTemplates, pluginTemplates, themeTemplates];
}

/**
 * This class provides takes set of core/plugin/theme modules, finds the template modules,
 * and makes an efficient lookup table for the resolver to use. It takes care of sourcing
 * component/route templates from themes/plugins, and also warns about clashes
 */
class DiscourseTemplateMap {
  templates = new Map();

  /**
   * Reset the TemplateMap to use the supplied module names. It is expected that the list
   * will be generated using `Object.keys(requirejs.entries)`.
   */
  setModuleNames(moduleNames) {
    this.templates.clear();

    for (const templateMap of buildPrioritizedMaps(moduleNames)) {
      for (const [path, modulesForPath] of templateMap) {
        for (const moduleForPath of modulesForPath) {
          this.#add(path, moduleForPath);
        }
      }
    }
  }

  #add(path, moduleName) {
    if (this.templates.has(path)) {
      const msg = `Duplicate templates found for '${path}': '${moduleName}' clashes with '${this.templates.get(path)}'`;

      if (isTesting()) {
        throw new Error(msg);
      } else {
        // eslint-disable-next-line no-console
        console.error(msg);
      }
    } else {
      this.templates.set(path, moduleName);
    }
  }

  /**
   * Resolve a template name to a module name, taking into account
   * theme/plugin namespaces and overrides.
   */
  resolve(name) {
    return this.templates.get(name);
  }
}

export default new DiscourseTemplateMap();
