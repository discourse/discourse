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

    // TODO: Figure out how why we need this.
    resolveOther(parsedName) {
      // If we end with the name we want, use it. This allows us to define components within plugins.
      const suffix = parsedName.type + "s/" + parsedName.fullNameWithoutType,
        dashed = dasherize(suffix),
        moduleName = lookupModuleBySuffix(dashed);

      let module;
      if (moduleName) {
        module = requirejs(moduleName, null, null, true /* force sync */);
        if (module && module["default"]) {
          return module["default"];
        }
      }

      return super.resolveOther(parsedName);
    }

    resolveHelper(parsedName) {
      return (
        findHelper(parsedName.fullNameWithoutType) ||
        this.resolveOther(parsedName)
      );
    }

    resolveRoute(parsedName) {
      if (parsedName.fullNameWithoutType === "basic") {
        return requirejs("discourse/routes/discourse", null, null, true)
          .default;
      }

      return this.resolveOther(parsedName);
    }

    resolveTemplate(parsedName) {
      return (
        this.findMobileTemplate(parsedName) ||
        this.findTemplate(parsedName) ||
        this.findLoadingTemplate(parsedName) ||
        Ember.TEMPLATES.not_found
      );
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
        templates = Ember.TEMPLATES;

      return (
        this.resolveOther(parsedName) ||
        templates[slashedType] ||
        templates[decamelized.replace(/[_-]/, "/")] ||
        this.findAdminTemplate(parsedName)
      );
    }

    // Try to find a template within a special admin namespace, e.g. adminEmail => admin/templates/email
    // (similar to how discourse lays out templates)
    findAdminTemplate(parsedName) {
      let decamelized = decamelize(parsedName.fullNameWithoutType);

      if (decamelized.startsWith("components")) {
        let comPath = `admin/templates/${decamelized}`;

        let compTemplate = Ember.TEMPLATES[comPath];
        if (compTemplate) {
          return compTemplate;
        }
      }

      if (decamelized === "admin") {
        return Ember.TEMPLATES["admin/templates/admin"];
      } else if (decamelized.startsWith("admin")) {
        decamelized = decamelized.replace(
          /^admin[_\-\.\/]/,
          "admin/templates/"
        );
        decamelized = decamelized.replace(/\./g, "_");

        return (
          Ember.TEMPLATES[decamelized] ||
          Ember.TEMPLATES[decamelized.replace(/-/g, "_")]
        );
      }
    }

    // It seems that this exists to provide a fallback for any template that ends with "loading".
    // This comes late in the series of checks so an explicit match would be matched before this.
    // It might be smart to actually check for a word boundary at the start.
    findLoadingTemplate(parsedName) {
      if (parsedName.fullNameWithoutType.match(/loading$/)) {
        return Ember.TEMPLATES.loading;
      }
    }
  };
}
