/* global Ember */
import { dasherize, decamelize } from "@ember/string";
import deprecated from "discourse-common/lib/deprecated";
import { findHelper } from "discourse-common/lib/helpers";
import SuffixTrie from "discourse-common/lib/suffix-trie";
import Resolver from "ember-resolver";
import { buildResolver as buildLegacyResolver } from "discourse-common/lib/legacy-resolver";

let _options = {};
let moduleSuffixTrie = null;

export function setResolverOption(name, value) {
  _options[name] = value;
}

export function getResolverOption(name) {
  return _options[name];
}

export function clearResolverOptions() {
  _options = {};
}

function lookupModuleBySuffix(suffix) {
  if (!moduleSuffixTrie) {
    moduleSuffixTrie = new SuffixTrie("/");
    Object.keys(requirejs.entries).forEach((name) => {
      if (!name.includes("/templates/")) {
        moduleSuffixTrie.add(name);
      }
    });
  }
  return moduleSuffixTrie.withSuffix(suffix, 1)[0];
}

export function buildResolver(baseName) {
  let LegacyResolver = buildLegacyResolver(baseName);

  return class extends Resolver {
    LegacyResolver = LegacyResolver;

    init(props) {
      super.init(props);
      this.legacyResolver = this.LegacyResolver.create(props);
    }

    resolveRouter(/* parsedName */) {
      const routerPath = `${baseName}/router`;
      if (requirejs.entries[routerPath]) {
        const module = requirejs(routerPath, null, null, true);
        return module.default;
      }
    }

    // We overwrite this instead of `normalize` so we still get the benefits of the cache.
    _normalize(fullName) {
      if (fullName === "app-events:main") {
        deprecated(
          "`app-events:main` has been replaced with `service:app-events`",
          { since: "2.4.0", dropFrom: "2.9.0.beta1" }
        );
        fullName = "service:app-events";
      }

      for (const [key, value] of Object.entries({
        "controller:discovery.categoryWithID": "controller:discovery.category",
        "controller:discovery.parentCategory": "controller:discovery.category",
        "controller:tags-show": "controller:tag-show",
        "controller:tags.show": "controller:tag.show",
        "controller:tagsShow": "controller:tagShow",
        "route:discovery.categoryWithID": "route:discovery.category",
        "route:discovery.parentCategory": "route:discovery.category",
        "route:tags-show": "route:tag-show",
        "route:tags.show": "route:tag.show",
        "route:tagsShow": "route:tagShow",
      })) {
        if (fullName === key) {
          deprecated(`${key} was replaced with ${value}`, { since: "2.6.0" });
          fullName = value;
        }
      }

      let normalized = super._normalize(fullName);

      // This is code that we don't really want to keep long term. The main situation where we need it is for
      // doing stuff like `controllerFor('adminWatchedWordsAction')` where the real route name
      // is actually `adminWatchedWords.action`. The default behavior for the former is to
      // normalize to `adminWatchedWordsAction` where the latter becomes `adminWatchedWords.action`.
      // While these end up looking up the same file ultimately, they are treated as different
      // items and so we can end up with two distinct version of the controller!
      const split = fullName.split(":");
      const type = split[0];
      if (
        split.length > 1 &&
        (type === "controller" || type === "route" || type === "template")
      ) {
        let corrected;
        // This should only apply when there's a dot or slash in the name
        if (split[1].includes(".") || split[1].includes("/")) {
          // Check to see if the dasherized version exists. If it does we want to
          // normalize to that eagerly so the normalized versions of the dotted/slashed and
          // dotless/slashless match.
          const dashed = dasherize(split[1].replace(/[\.\/]/g, "-"));

          const adminBase = `admin/${type}s/`;
          const wizardBase = `wizard/${type}s/`;
          if (
            lookupModuleBySuffix(`${type}s/${dashed}`) ||
            requirejs.entries[adminBase + dashed] ||
            requirejs.entries[adminBase + dashed.replace(/^admin[-]/, "")] ||
            requirejs.entries[
              adminBase + dashed.replace(/^admin[-]/, "").replace(/-/g, "_")
            ] ||
            requirejs.entries[wizardBase + dashed] ||
            requirejs.entries[wizardBase + dashed.replace(/^wizard[-]/, "")] ||
            requirejs.entries[
              wizardBase + dashed.replace(/^wizard[-]/, "").replace(/-/g, "_")
            ]
          ) {
            corrected = type + ":" + dashed;
          }
        }

        if (corrected && corrected !== normalized) {
          normalized = corrected;
        }
      }

      return normalized;
    }

    chooseModuleName(moduleName, parsedName) {
      let resolved = super.chooseModuleName(moduleName, parsedName);
      if (resolved) {
        return resolved;
      }

      const standard = parsedName.fullNameWithoutType;

      let variants = [standard];

      if (standard.includes("/")) {
        variants.push(parsedName.fullNameWithoutType.replace(/\//g, "-"));
      }

      for (let name of variants) {
        // If we end with the name we want, use it. This allows us to define components within plugins.
        const suffix = parsedName.type + "s/" + name;
        resolved = lookupModuleBySuffix(dasherize(suffix));
        if (resolved) {
          return resolved;
        }
      }
    }

    resolveOther(parsedName) {
      let resolved = super.resolveOther(parsedName);
      if (!resolved) {
        let legacyParsedName = this.legacyResolver.parseName(
          `${parsedName.type}:${parsedName.fullName}`
        );
        resolved = this.legacyResolver.resolveOther(legacyParsedName);
        if (resolved) {
          deprecated(
            `Unable to resolve with new resolver, but resolved with legacy resolver: ${parsedName.fullName}`
          );
        }
      }
      return resolved;
    }

    resolveHelper(parsedName) {
      return findHelper(parsedName.fullNameWithoutType);
    }

    // If no match is found here, the resolver falls back to `resolveOther`.
    resolveRoute(parsedName) {
      if (parsedName.fullNameWithoutType === "basic") {
        return requirejs("discourse/routes/discourse", null, null, true)
          .default;
      }
    }

    resolveTemplate(parsedName) {
      return (
        this.findPluginMobileTemplate(parsedName) ||
        this.findPluginTemplate(parsedName) ||
        this.findMobileTemplate(parsedName) ||
        this.findTemplate(parsedName) ||
        this.findAdminTemplate(parsedName) ||
        this.findWizardTemplate(parsedName) ||
        this.findLoadingTemplate(parsedName) ||
        this.findConnectorTemplate(parsedName) ||
        Ember.TEMPLATES.not_found
      );
    }

    findLoadingTemplate(parsedName) {
      if (parsedName.fullNameWithoutType.match(/loading$/)) {
        return Ember.TEMPLATES.loading;
      }
    }

    findConnectorTemplate(parsedName) {
      if (parsedName.fullName.startsWith("template:connectors/")) {
        const connectorParsedName = this.parseName(
          parsedName.fullName
            .replace("template:connectors/", "template:")
            .replace("components/", "")
        );
        return this.findTemplate(connectorParsedName, "javascripts/");
      }
    }

    findPluginTemplate(parsedName) {
      return this.findTemplate(parsedName, "javascripts/");
    }

    findPluginMobileTemplate(parsedName) {
      if (_options.mobileView) {
        return this.findTemplate(parsedName, "javascripts/mobile/");
      }
    }

    findMobileTemplate(parsedName) {
      if (_options.mobileView) {
        return this.findTemplate(parsedName, "mobile/");
      }
    }

    findTemplate(parsedName, prefix) {
      prefix = prefix || "";

      const withoutType = parsedName.fullNameWithoutType,
        underscored = decamelize(withoutType).replace(/-/g, "_"),
        segments = withoutType.split("/"),
        templates = Ember.TEMPLATES;

      return (
        // Convert dots and dashes to slashes
        templates[prefix + withoutType.replace(/[\.-]/g, "/")] ||
        // Default unmodified behavior of original resolveTemplate.
        templates[prefix + withoutType] ||
        // Underscored without namespace
        templates[prefix + underscored] ||
        // Underscored with first segment as directory
        templates[prefix + underscored.replace("_", "/")] ||
        // Underscore only the last segment
        templates[
          `${prefix}${segments.slice(0, -1).join("/")}/${segments[
            segments.length - 1
          ].replace(/-/g, "_")}`
        ] ||
        // All dasherized
        templates[prefix + withoutType.replace(/\//g, "-")]
      );
    }

    // Try to find a template within a special admin namespace, e.g. adminEmail => admin/templates/email
    // (similar to how discourse lays out templates)
    findAdminTemplate(parsedName) {
      if (parsedName.fullNameWithoutType === "admin") {
        return Ember.TEMPLATES["admin/templates/admin"];
      }

      let namespaced, match;

      if (parsedName.fullNameWithoutType.startsWith("components/")) {
        // Look up components as-is
      } else if (/^admin[_\.-]/.test(parsedName.fullNameWithoutType)) {
        namespaced = parsedName.fullNameWithoutType.slice(6);
      } else if (
        (match = parsedName.fullNameWithoutType.match(/^admin([A-Z])(.+)$/))
      ) {
        namespaced = `${match[1].toLowerCase()}${match[2]}`;
      }

      let resolved;

      if (namespaced) {
        let adminParsedName = this.parseName(`template:${namespaced}`);
        resolved =
          // Built-in
          this.findTemplate(adminParsedName, "admin/templates/") ||
          // Plugin
          this.findTemplate(adminParsedName, "javascripts/admin/");
      }

      resolved ??=
        // Built-in
        this.findTemplate(parsedName, "admin/templates/") ||
        // Plugin
        this.findTemplate(parsedName, "javascripts/admin/");

      return resolved;
    }

    findWizardTemplate(parsedName) {
      if (parsedName.fullNameWithoutType === "wizard") {
        return Ember.TEMPLATES["wizard/templates/wizard"];
      }

      let namespaced;

      if (parsedName.fullNameWithoutType.startsWith("components/")) {
        // Look up components as-is
        namespaced = parsedName.fullNameWithoutType;
      } else if (/^wizard[_\.-]/.test(parsedName.fullNameWithoutType)) {
        // This may only get hit for the loading routes and may be removable.
        namespaced = parsedName.fullNameWithoutType.slice(7);
      }

      if (namespaced) {
        let adminParsedName = this.parseName(
          `template:wizard/templates/${namespaced}`
        );
        return this.findTemplate(adminParsedName);
      }
    }
  };
}
