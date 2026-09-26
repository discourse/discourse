import { lookup } from "discourse/lib/service";
import HumanActivityTrackerService from "discourse/services/human-activity-tracker";
export default {
  after: "inject-objects",

  initialize(owner) {
    lookup(owner, HumanActivityTrackerService).start();
  },
};
