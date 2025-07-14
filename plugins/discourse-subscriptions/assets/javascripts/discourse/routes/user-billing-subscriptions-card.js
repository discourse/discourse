import Route from "@ember/routing/route";

export default class UserBillingSubscriptionsCardRoute extends Route {
  model(params) {
    return params["stripe-subscription-id"];
  }
}
