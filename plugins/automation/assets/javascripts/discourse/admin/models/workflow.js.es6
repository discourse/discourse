import RestModel from "discourse/models/rest";
import Plan from "./plan";
import Trigger from "./trigger";

const Workflow = RestModel.extend({});

Workflow.reopenClass({
  munge(json) {
    if (json.trigger) {
      json.trigger = Trigger.create(json.trigger);
    }
    if (json.plans && json.plans.length) {
      json.plans = json.plans.map(p => Plan.create(p));
    }
    return json;
  }
});

export default Workflow;
