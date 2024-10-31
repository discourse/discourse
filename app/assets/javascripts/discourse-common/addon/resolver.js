import { dasherize, decamelize } from "@ember/string";
import Resolver from "ember-resolver";
import deprecated from "discourse-common/lib/deprecated";
import DiscourseTemplateMap from "discourse-common/lib/discourse-template-map";
import { findHelper } from "discourse-common/lib/helpers";
import SuffixTrie from "discourse-common/lib/suffix-trie";

let _options = {};
let moduleSuffixTrie = null;

const DEPRECATED_MODULES = new Map(
  Object.entries({
    "controller:discovery.categoryWithID": {
      newName: "controller:discovery.category",
      since: "2.6.0",
    },
    "controller:discovery.parentCategory": {
      newName: "controller:discovery.category",
      since: "2.6.0",
    },
    "controller:tags-show": { newName: "controller:tag-show", since: "2.6.0" },
    "controller:tags.show": { newName: "controller:tag.show", since: "2.6.0" },
    "controller:tagsShow": { newName: "controller:tagShow", since: "2.6.0" },
    "route:discovery.categoryWithID": {
      newName: "route:discovery.category",
      since: "2.6.0",
    },
    "route:discovery.parentCategory": {
      newName: "route:discovery.category",
      since: "2.6.0",
    },
    "route:tags-show": { newName: "route:tag-show", since: "2.6.0" },
    "route:tags.show": { newName: "route:tag.show", since: "2.6.0" },
    "route:tagsShow": { newName: "route:tagShow", since: "2.6.0" },
    "app-events:main": {
      newName: "service:app-events",
      since: "2.4.0",
      dropFrom: "2.9.0.beta1",
    },
    // Deprecations below are silenced because they're in widespread use, and upgrading
    // themes/plugins right now would break their compatibility with the stable branch.
    // These should be unsilenced for the release of 2.9.0 stable.
    "store:main": {
      newName: "service:store",
      since: "2.8.0.beta8",
      dropFrom: "2.9.0.beta1",
      silent: true,
    },
    "search-service:main": {
      newName: "service:search",
      since: "2.8.0.beta8",
      dropFrom: "2.9.0.beta1",
      silent: true,
    },
    "key-value-store:main": {
      newName: "service:key-value-store",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "pm-topic-tracking-state:main": {
      newName: "service:pm-topic-tracking-state",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "message-bus:main": {
      newName: "service:message-bus",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "site-settings:main": {
      newName: "service:site-settings",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "capabilities:main": {
      newName: "service:capabilities",
      since: "3.1.0.beta4",
      dropFrom: "3.2.0.beta1",
      silent: true,
    },
    "current-user:main": {
      newName: "service:current-user",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "session:main": {
      newName: "service:session",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "site:main": {
      newName: "service:site",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "topic-tracking-state:main": {
      newName: "service:topic-tracking-state",
      since: "2.9.0.beta7",
      dropFrom: "3.0.0",
      silent: true,
    },
    "controller:composer": {
      newName: "service:composer",
      since: "3.1.0.beta3",
      dropFrom: "3.2.0",
      silent: true,
    },
  })
);

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
    const searchPaths = [
      "discourse/", // Includes themes/plugins
      "discourse-common/",
      "select-kit/",
      "admin/",
    ];
    Object.keys(requirejs.entries).forEach((name) => {
      if (
        searchPaths.some((s) => name.startsWith(s)) &&
        !name.includes("/templates/")
      ) {
        moduleSuffixTrie.add(name);
      }
    });
  }
  return (
    moduleSuffixTrie.withSuffix(suffix, 1)[0] ||
    moduleSuffixTrie.withSuffix(`${suffix}/index`, 1)[0]
  );
}

export function expireModuleTrieCache() {
  moduleSuffixTrie = null;
}

export function buildResolver(baseName) {
  return class extends Resolver {
    resolveRouter(/* parsedName */) {
      const routerPath = `${baseName}/router`;
      if (requirejs.entries[routerPath]) {
        const module = requirejs(routerPath, null, null, true);
        return module.default;
      }
    }

    // We overwrite this instead of `normalize` so we still get the benefits of the cache.
    _normalize(fullName) {
      const deprecationInfo = DEPRECATED_MODULES.get(fullName);
      if (deprecationInfo) {
        if (!deprecationInfo.silent) {
          deprecated(
            `"${fullName}" is deprecated, use "${deprecationInfo.newName}" instead`,
            {
              since: deprecationInfo.since,
              dropFrom: deprecationInfo.dropFrom,
              id: "discourse.resolver-resolutions",
            }
          );
        }
        fullName = deprecationInfo.newName;
      }

      const split = fullName.split(":");
      const type = split[0];

      let normalized;
      if (type === "template" && split[1]?.includes("connectors/")) {
        // The default normalize implementation will skip dasherizing component template names
        // We need the same for our connector templates names
        normalized = "template:" + split[1].replace(/_/g, "-");
      } else {
        normalized = super._normalize(fullName);
      }

      // This is code that we don't really want to keep long term. The main situation where we need it is for
      // doing stuff like `controllerFor('adminWatchedWordsAction')` where the real route name
      // is actually `adminWatchedWords.action`. The default behavior for the former is to
      // normalize to `adminWatchedWordsAction` where the latter becomes `adminWatchedWords.action`.
      // While these end up looking up the same file ultimately, they are treated as different
      // items and so we can end up with two distinct version of the controller!
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
          if (
            lookupModuleBySuffix(`${type}s/${dashed}`) ||
            requirejs.entries[adminBase + dashed] ||
            requirejs.entries[adminBase + dashed.replace(/^admin[-]/, "")] ||
            requirejs.entries[
              adminBase + dashed.replace(/^admin[-]/, "").replace(/-/g, "_")
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

    findModuleName(parsedName) {
      let resolved = super.findModuleName(parsedName);

      if (resolved) {
        return resolved;
      }

      const standard = parsedName.fullNameWithoutType;
      let variants = [standard];

      if (standard.includes("/")) {
        variants.push(standard.replace(/\//g, "-"));
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
        this.findMobileTemplate(parsedName) ||
        this.findTemplate(parsedName) ||
        this.findAdminTemplate(parsedName) ||
        this.findLoadingTemplate(parsedName) ||
        this.findConnectorTemplate(parsedName) ||
        this.discourseTemplateModule("not_found")
      );
    }

    findLoadingTemplate(parsedName) {
      if (parsedName.fullNameWithoutType.match(/loading$/)) {
        return this.discourseTemplateModule("loading");
      }
    }

    findConnectorTemplate(parsedName) {
      if (parsedName.fullName.startsWith("template:connectors/")) {
        const connectorParsedName = this.parseName(
          parsedName.fullName
            .replace("template:connectors/", "template:")
            .replace("components/", "")
        );
        return this.findTemplate(connectorParsedName);
      }
    }

    findMobileTemplate(parsedName) {
      const result = this.findTemplate(parsedName, "mobile/");
      if (result) {
        deprecated(
          `Mobile-specific hbs templates are deprecated. Use responsive CSS or {{#if this.site.mobileView}} instead. [${parsedName}]`,
          {
            id: "discourse.mobile-templates",
          }
        );
        return result;
      }
      if (_options.mobileView) {
        return result;
      }
    }

    /**
     * Given a template path, this function will return a template, taking into account
     * priority rules for theme and plugin overrides. See `lib/discourse-template-map.js`
     */
    discourseTemplateModule(name) {
      const resolvedName = DiscourseTemplateMap.resolve(name);
      if (resolvedName) {
        return require(resolvedName).default;
      }
    }

    findTemplate(parsedName, prefix) {
      prefix = prefix || "";

      const withoutType = parsedName.fullNameWithoutType,
        underscored = decamelize(withoutType).replace(/-/g, "_"),
        segments = withoutType.split("/");

      return (
        // Convert dots and dashes to slashes
        this.discourseTemplateModule(
          prefix + withoutType.replace(/[\.-]/g, "/")
        ) ||
        // Default unmodified behavior of original resolveTemplate.
        this.discourseTemplateModule(prefix + withoutType) ||
        // Underscored without namespace
        this.discourseTemplateModule(prefix + underscored) ||
        // Underscored with first segment as directory
        this.discourseTemplateModule(prefix + underscored.replace("_", "/")) ||
        // Underscore only the last segment
        this.discourseTemplateModule(
          `${prefix}${segments.slice(0, -1).join("/")}/${segments[
            segments.length - 1
          ].replace(/-/g, "_")}`
        ) ||
        // All dasherized
        this.discourseTemplateModule(prefix + withoutType.replace(/\//g, "-"))
      );
    }

    // Try to find a template within a special admin namespace, e.g. adminEmail => admin/templates/email
    // (similar to how discourse lays out templates)
    findAdminTemplate(parsedName) {
      if (parsedName.fullNameWithoutType === "admin") {
        return this.discourseTemplateModule("admin/templates/admin");
      }

      let namespaced, match;

      if (parsedName.fullNameWithoutType.startsWith("components/")) {
        return (
          this.findTemplate(parsedName, "admin/templates/") ||
          this.findTemplate(parsedName, "admin/") // Nested under discourse/templates/admin (e.g. from plugins)
        );
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
          this.findTemplate(adminParsedName, "admin/templates/") ||
          this.findTemplate(parsedName, "admin/templates/") ||
          this.findTemplate(adminParsedName, "admin/"); // Nested under discourse/templates/admin (e.g. from plugin)
      }

      return resolved;
    }
  };
}
