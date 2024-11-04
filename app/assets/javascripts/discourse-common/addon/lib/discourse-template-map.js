import deprecated from "./deprecated";

const pluginRegex = /^discourse\/plugins\/([^\/]+)\/(.*)$/;
const themeRegex = /^discourse\/theme-([^\/]+)\/(.*)$/;

function appendToCache(cache, key, value) {
  let cachedValue = cache.get(key);
  cachedValue ??= [];
  cachedValue.push(value);
  cache.set(key, cachedValue);
}

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

/**
 * This class provides takes set of core/plugin/theme modules, finds the template modules,
 * and makes an efficient lookup table for the resolver to use. It takes care of sourcing
 * component/route templates from themes/plugins, and also handles template overrides.
 */
class DiscourseTemplateMap {
  coreTemplates = new Map();
  pluginTemplates = new Map();
  themeTemplates = new Map();
  prioritizedCaches = [
    this.themeTemplates,
    this.pluginTemplates,
    this.coreTemplates,
  ];

  /**
   * Reset the TemplateMap to use the supplied module names. It is expected that the list
   * will be generated using `Object.keys(requirejs.entries)`.
   */
  setModuleNames(moduleNames) {
    this.coreTemplates.clear();
    this.pluginTemplates.clear();
    this.themeTemplates.clear();
    for (const moduleName of moduleNames) {
      if (isInRecognisedNamespace(moduleName) && isTemplate(moduleName)) {
        this.#add(moduleName);
      }
    }
  }

  #add(originalPath) {
    let path = originalPath;

    let pluginMatch, themeMatch, cache;
    if ((pluginMatch = path.match(pluginRegex))) {
      path = pluginMatch[2];
      cache = this.pluginTemplates;
    } else if ((themeMatch = path.match(themeRegex))) {
      path = themeMatch[2];
      cache = this.themeTemplates;
    } else {
      cache = this.coreTemplates;
    }

    path = path.replace(/^discourse\/templates\//, "");

    appendToCache(cache, path, originalPath);
  }

  /**
   * Resolve a template name to a module name, taking into account
   * theme/plugin namespaces and overrides.
   */
  resolve(name) {
    const [themeMatch, pluginMatch, coreMatch] = this.prioritizedCaches.map(
      (cache) => {
        const val = cache.get(name);
        if (val) {
          return val[val.length - 1];
        }
      }
    );

    if ((themeMatch || pluginMatch) && coreMatch) {
      deprecated(
        `[${
          themeMatch || pluginMatch
        }] Overriding templates is deprecated, and will soon be disabled. Use plugin outlets, CSS, or other customization APIs instead.`,
        {
          id: "discourse.resolver-template-overrides",
          url: "https://meta.discourse.org/t/247487",
        }
      );
    }

    return themeMatch || pluginMatch || coreMatch;
  }

  /**
   * List all available template keys, after theme/plugin namespaces have
   * been stripped.
   */
  keys() {
    const uniqueKeys = new Set([
      ...this.coreTemplates.keys(),
      ...this.pluginTemplates.keys(),
      ...this.themeTemplates.keys(),
    ]);
    return [...uniqueKeys];
  }
}

export default new DiscourseTemplateMap();
