import Route from "@ember/routing/route";

export default class AvailabilityGroupRoute extends Route {
  model(params) {
    return { groupName: params.group_name };
  }
}
