import BaseCommunitySectionLink from "discourse/lib/sidebar/base-community-section-link";

export let customSectionLinks = [];
export let secondaryCustomSectionLinks = [];

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
 * Appends an additional section link to the Community section under the "More..." links drawer.
 *
 * @callback addSectionLinkCallback
 * @param {BaseCommunitySectionLink} baseCommunitySectionLink Factory class to inherit from.
 * @returns {BaseCommunitySectionLink} A class that extends BaseCommunitySectionLink.
 *
 * @param {(addSectionLinkCallback|Object)} args - A callback function or an Object.
 * @param {string} args.name - The name of the link. Needs to be dasherized and lowercase.
 * @param {string=} args.route - The Ember route name to generate the href attribute for the link.
 * @param {string=} args.href - The href attribute for the link.
 * @param {string=} args.title - The title attribute for the link.
 * @param {string} args.text - The text to display for the link.
 * @param {Boolean} [secondary] - Determines whether the section link should be added to the main or secondary section in the "More..." links drawer.
 */
export function addSectionLink(args, secondary) {
  const links = secondary ? secondaryCustomSectionLinks : customSectionLinks;

  if (typeof args === "function") {
    links.push(args.call(this, BaseCommunitySectionLink));
  } else {
    const klass = class extends BaseCommunitySectionLink {
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

    links.push(klass);
  }
}

export function resetDefaultSectionLinks() {
  customSectionLinks.length = 0;
  secondaryCustomSectionLinks.length = 0;
}
