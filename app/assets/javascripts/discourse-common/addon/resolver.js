/* eslint-disable no-undef */
import { dasherize, decamelize } from "@ember/string";
import deprecated from "discourse-common/lib/deprecated";
import { findHelper } from "discourse-common/lib/helpers";
import SuffixTrie from "discourse-common/lib/suffix-trie";
import Resolver from "ember-resolver";

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
  return class DiscourseResolver extends Resolver {
    parseName(fullName) {
      let parsed = super.parseName(fullName);
      return parsed;
    }

    resolveRouter(parsedName) {
      const routerPath = `${baseName}/router`;
      if (requirejs.entries[routerPath]) {
        const module = requirejs(routerPath, null, null, true);
        return module.default;
      }
      return this.resolveOther(parsedName);
    }

    _normalize(fullName) {
      if (fullName === "app-events:main") {
        deprecated(
          "`app-events:main` has been replaced with `service:app-events`",
          { since: "2.4.0", dropFrom: "2.9.0.beta1" }
        );
        return "service:app-events";
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
          return value;
        }
      }

      // A) Convert underscores to dashes
      // B) Convert camelCase to dash-case, except for components (their
      //    templates) and helpers where we want to avoid shadowing camelCase
      //    expressions
      // C) replace `.` with `/` in order to make nested controllers work in the following cases
      //      1. `needs: ['posts/post']`
      //      2. `{{render "posts/post"}}`
      //      3. `this.render('posts/post')` from Route

      let split = fullName.split(":");
      if (split.length > 1) {
        let type = split[0];

        const appBase = `${baseName}/${split[0]}s/`;
        const adminBase = "admin/" + split[0] + "s/";

        // Allow render 'admin/templates/xyz' too
        split[1] = split[1].replace(/[\/\.]templates\b/, "");

        if (
          type === "component" ||
          type === "helper" ||
          type === "modifier" ||
          (type === "template" && split[1].startsWith("components/"))
        ) {
          return type + ":" + split[1].replace(/_/g, "-");
        } else {
          // Try slashes
          let slashed = dasherize(split[1].replace(/\./g, "/"));
          if (
            requirejs.entries[appBase + slashed] ||
            requirejs.entries[adminBase + slashed.replace(/^admin\//, "")]
          ) {
            return type + ":" + slashed;
          }

          // Try with dashes instead of slashes
          let dashed = dasherize(split[1].replace(/\./g, "-"));
          return type + ":" + dashed;
        }
      } else {
        return fullName;
      }
    }

    customResolve(parsedName) {
      // If we end with the name we want, use it. This allows us to define components within plugins.
      const suffix = parsedName.type + "s/" + parsedName.fullNameWithoutType,
        dashed = dasherize(suffix),
        moduleName = lookupModuleBySuffix(dashed);

      let module;
      if (moduleName) {
        module = requirejs(moduleName, null, null, true /* force sync */);
        if (module && module["default"]) {
          module = module["default"];
        }
      }
      return module;
    }

    resolveWidget(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveAdapter(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveModel(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveView(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveHelper(parsedName) {
      return (
        findHelper(parsedName.fullNameWithoutType) ||
        this.customResolve(parsedName) ||
        super.resolveOther(parsedName)
      );
    }

    resolveController(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveComponent(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveService(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveRawView(parsedName) {
      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveRoute(parsedName) {
      if (parsedName.fullNameWithoutType === "basic") {
        return requirejs("discourse/routes/discourse", null, null, true)
          .default;
      }

      return this.customResolve(parsedName) || this.resolveOther(parsedName);
    }

    resolveTemplate(parsedName) {
      let resolved =
        this.findPluginMobileTemplate(parsedName) ||
        this.findPluginTemplate(parsedName) ||
        this.findMobileTemplate(parsedName) ||
        this.findTemplate(parsedName) ||
        this.findLoadingTemplate(parsedName) ||
        this.findConnectorTemplate(parsedName) ||
        Ember.TEMPLATES.not_found;
      return resolved;
    }

    findPluginTemplate(parsedName) {
      const pluginParsedName = this.parseName(
        parsedName.fullName.replace("template:", "template:javascripts/")
      );
      return this.findTemplate(pluginParsedName);
    }

    findPluginMobileTemplate(parsedName) {
      if (_options.mobileView) {
        let pluginParsedName = this.parseName(
          parsedName.fullName.replace(
            "template:",
            "template:javascripts/mobile/"
          )
        );
        return this.findTemplate(pluginParsedName);
      }
    }

    findMobileTemplate(parsedName) {
      if (_options.mobileView) {
        let mobileParsedName = this.parseName(
          parsedName.fullName.replace("template:", "template:mobile/")
        );
        return this.findTemplate(mobileParsedName);
      }
    }

    findTemplate(parsedName) {
      const withoutType = parsedName.fullNameWithoutType,
        slashedType = withoutType.replace(/\./g, "/"),
        decamelized = decamelize(withoutType),
        dashed = decamelized.replace(/\./g, "-").replace(/\_/g, "-"),
        templates = Ember.TEMPLATES;

      return (
        this.resolveOther(parsedName) ||
        templates[slashedType] ||
        templates[withoutType] ||
        templates[withoutType.replace(/\.raw$/, "")] ||
        templates[dashed] ||
        templates[decamelized.replace(/\./, "/")] ||
        templates[decamelized.replace(/[_-]/, "/")] ||
        templates[`${baseName}/templates/${withoutType}`] ||
        this.findAdminTemplate(parsedName) ||
        this.findUnderscoredTemplate(parsedName)
      );
    }

    findUnderscoredTemplate(parsedName) {
      let decamelized = decamelize(parsedName.fullNameWithoutType);
      let underscored = decamelized.replace(/\-/g, "_");
      return Ember.TEMPLATES[underscored];
    }

    // Try to find a template within a special admin namespace, e.g. adminEmail => admin/templates/email
    // (similar to how discourse lays out templates)
    findAdminTemplate(parsedName) {
      let decamelized = decamelize(parsedName.fullNameWithoutType);
      if (decamelized.startsWith("components")) {
        let comPath = `admin/templates/${decamelized}`;
        const compTemplate =
          Ember.TEMPLATES[`javascripts/${comPath}`] || Ember.TEMPLATES[comPath];
        if (compTemplate) {
          return compTemplate;
        }
      }

      if (decamelized === "javascripts/admin") {
        return Ember.TEMPLATES["admin/templates/admin"];
      }

      if (
        decamelized.startsWith("admin") ||
        decamelized.startsWith("javascripts/admin")
      ) {
        decamelized = decamelized.replace(
          /^admin[_\-\.\/]/,
          "admin/templates/"
        );
        decamelized = decamelized.replace(/\./g, "_");

        const dashed = decamelized.replace(/_/g, "-");
        return (
          Ember.TEMPLATES[decamelized] ||
          Ember.TEMPLATES[dashed] ||
          Ember.TEMPLATES[dashed.replace(/-/, "_")] ||
          Ember.TEMPLATES[dashed.replace("admin-", "admin/")]
        );
      }
    }

    findLoadingTemplate(parsedName) {
      if (parsedName.fullNameWithoutType.match(/loading$/)) {
        return Ember.TEMPLATES.loading;
      }
    }

    findConnectorTemplate(parsedName) {
      const full = parsedName.fullNameWithoutType.replace("components/", "");
      if (full.indexOf("connectors") === 0) {
        return Ember.TEMPLATES[`javascripts/${full}`];
      }
    }
  };
}
