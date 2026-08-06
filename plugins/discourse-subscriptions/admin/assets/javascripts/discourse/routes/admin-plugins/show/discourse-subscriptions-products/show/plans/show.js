import Route from "@ember/routing/route";
import { hash } from "rsvp";
import Group from "discourse/models/group";
import AdminPlan from "discourse/plugins/discourse-subscriptions/discourse/models/admin-plan";

export default class AdminPluginsDiscourseSubscriptionsProductsShowPlansShowRoute extends Route {
  model(params) {
    const id = params["plan-id"];
    const product = this.modelFor(
      "adminPlugins.show.discourse-subscriptions-products.show"
    ).product;
    let plan;

    if (id === "new") {
      plan = AdminPlan.create({
        active: true,
        isNew: true,
        interval: "month",
        type: "recurring",
        isRecurring: true,
        currency: this.siteSettings.discourse_subscriptions_currency,
        product: product.get("id"),
        metadata: {
          group_name: null,
        },
      });
    } else {
      plan = AdminPlan.find(id).then((result) => {
        result.isRecurring = result.type === "recurring";

        return result;
      });
    }

    const groups = Group.findAll({ ignore_automatic: true });

    return hash({ plan, product, groups });
  }

  renderTemplate() {
    this.render(
      "adminPlugins.show.discourse-subscriptions-products.show.plans.show",
      {
        into: "adminPlugins.show.discourse-subscriptions-products",
        outlet: "main",
        controller:
          "adminPlugins.show.discourse-subscriptions-products.show.plans.show",
      }
    );
  }
}
