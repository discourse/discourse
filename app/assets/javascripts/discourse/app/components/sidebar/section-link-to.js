import Ember from "ember";

export default class SidebarSectionLinkTo extends Ember.LinkComponent {
  // Overriding the private function here because the behavior of the component when used with the `current-when`
  // attribute does not seem to follow what was mentioned in the docs: "A link will be active if current-when is true or
  // the current route is the route this link would transition to". When the `current-when` attribute is used, the
  // `route` and `query` attributes are ignored which is not what we want. In addition, we're stuck on Ember 3.15 at
  // the moment and are awaiting the upgrade to the latest supported Ember version before I can determine if this is a
  // bug and report it as such.
  _isActive(routerState) {
    if (this.loading) {
      return false;
    }

    let currentWhen = this["current-when"];

    if (typeof currentWhen === "boolean") {
      return currentWhen;
    }

    let isCurrentWhenSpecified = Boolean(currentWhen);

    if (isCurrentWhenSpecified) {
      currentWhen = currentWhen.split(" ");
    } else {
      currentWhen = [this._route];
    }

    let { _models: models, _query: query, _routing: routing } = this;

    for (let i = 0; i < currentWhen.length; i++) {
      if (
        routing.isActiveForRoute(
          models,
          query,
          currentWhen[i],
          routerState,
          // **custom code override start**
          // we always want query params to be considered
          false
          // isCurrentWhenSpecified
          // **custom code override end**
        )
      ) {
        return true;
      }
    }

    return false;
  }
}
