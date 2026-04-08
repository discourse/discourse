import Service, { service } from "@ember/service";

export default class DataExplorerMode extends Service {
  @service siteSettings;

  get isFull() {
    return this.siteSettings.data_explorer_mode === "full";
  }

  get isDisabled() {
    return this.siteSettings.data_explorer_mode === "disabled";
  }
}
