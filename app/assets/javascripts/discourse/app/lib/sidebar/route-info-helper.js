export default class RouteInfoHelper {
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
