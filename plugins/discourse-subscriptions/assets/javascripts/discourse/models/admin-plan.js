import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import Plan from "discourse/plugins/discourse-subscriptions/discourse/models/plan";

export default class AdminPlan extends Plan {
  static findAll(data) {
    return ajax("/s/admin/plans", { method: "get", data }).then((result) =>
      result.map((plan) => AdminPlan.create(plan))
    );
  }

  static find(id) {
    return ajax(`/s/admin/plans/${id}`, { method: "get" }).then((plan) =>
      AdminPlan.create(plan)
    );
  }

  isNew = false;
  name = "";
  interval = "month";
  unit_amount = 0;
  intervals = ["day", "week", "month", "year"];
  metadata = {};

  @discourseComputed("trial_period_days")
  parseTrialPeriodDays(trialDays) {
    if (trialDays) {
      return parseInt(0 + trialDays, 10);
    } else {
      return 0;
    }
  }

  save() {
    const data = {
      nickname: this.nickname,
      interval: this.interval,
      amount: this.unit_amount,
      currency: this.currency,
      trial_period_days: this.parseTrialPeriodDays,
      type: this.type,
      product: this.product,
      metadata: this.metadata,
      active: this.active,
    };

    return ajax("/s/admin/plans", { method: "post", data });
  }

  update() {
    const data = {
      nickname: this.nickname,
      trial_period_days: this.parseTrialPeriodDays,
      metadata: this.metadata,
      active: this.active,
    };

    return ajax(`/s/admin/plans/${this.id}`, { method: "patch", data });
  }
}
