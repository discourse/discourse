import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import AdminConfigAreaSidebarExperiment from "admin/components/admin-config-area-sidebar-experiment";

const CONFIG_AREA_COMPONENT_MAP = {
  "sidebar-experiment": AdminConfigAreaSidebarExperiment,
};

export default class AdminRevampConfigAreaRoute extends Route {
  @service router;

  async model(params) {
    return {
      area: params.area,
      configAreaComponent: CONFIG_AREA_COMPONENT_MAP[dasherize(params.area)],
    };
  }
}
