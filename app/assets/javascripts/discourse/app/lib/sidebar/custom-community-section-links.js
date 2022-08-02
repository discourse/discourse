import BaseSectionLink from "discourse/lib/sidebar/community-section/base-section-link";

export let customSectionLinks = [];
class RouteInfoHelper {
  constructor(router, url) {
    this.routeInfo = router.recognize(url);
  }

  get route() {
    return this.routeInfo.name;
  }

  get models() {
    return this.#getParameters;
  }

  get query() {
    return this.routeInfo.queryParams;
  }

  /**
   * Extracted from https://github.com/emberjs/rfcs/issues/658
   * Retrieves all parameters for a `RouteInfo` object and its parents in
   * correct oder, so that you can pass them to e.g.
   * `transitionTo(routeName, ...params)`.
   */
  get #getParameters() {
    let allParameters = [];
    let current = this.routeInfo;

    do {
      const { params, paramNames } = current;
      const currentParameters = paramNames.map((n) => params[n]);
      allParameters = [...currentParameters, ...allParameters];
    } while ((current = current.parent));

    return allParameters;
  }
}

/**
 * Appends an additional section link under the topics section
 * @callback addSectionLinkCallback
 * @param {BaseSectionLink} baseSectionLink Factory class to inherit from.
 * @returns {BaseSectionLink} A class that extends BaseSectionLink.
 *
 * @param {(addSectionLinkCallback|Object)} args - A callback function or an Object.
 * @param {string} arg.name - The name of the link. Needs to be dasherized and lowercase.
 * @param {string=} arg.route - The Ember route name to generate the href attribute for the link.
 * @param {string=} arg.href - The href attribute for the link.
 * @param {string=} arg.title - The title attribute for the link.
 * @param {string} arg.text - The text to display for the link.
 */
export function addSectionLink(args) {
  if (typeof args === "function") {
    customSectionLinks.push(args.call(this, BaseSectionLink));
  } else {
    const klass = class extends BaseSectionLink {
      constructor() {
        super(...arguments);

        if (args.href) {
          this.routeInfoHelper = new RouteInfoHelper(this.router, args.href);
        }
      }

      get name() {
        return args.name;
      }

      get route() {
        if (args.href) {
          return this.routeInfoHelper.route;
        } else {
          return args.route;
        }
      }

      get models() {
        if (args.href) {
          return this.routeInfoHelper.models;
        }
      }

      get query() {
        if (args.href) {
          return this.routeInfoHelper.query;
        }
      }

      get text() {
        return args.text;
      }

      get title() {
        return args.title;
      }
    };

    customSectionLinks.push(klass);
  }
}

export function resetDefaultSectionLinks() {
  customSectionLinks = [];
}
