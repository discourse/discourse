import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class Header extends Service {
  @service siteSettings;

  @tracked topic = null;
  @tracked hamburgerVisible = false;
  @tracked userVisible = false;
  @tracked anyWidgetHeaderOverrides = false;

  get useGlimmerHeader() {
    if (this.siteSettings.glimmer_header_mode === "disabled") {
      return false;
    } else if (this.siteSettings.glimmer_header_mode === "enabled") {
      return true;
    } else {
      // Auto
      if (this.anyWidgetHeaderOverrides) {
        // eslint-disable-next-line no-console
        console.warn(
          "Using legacy 'widget' header because themes and/or plugins are using deprecated APIs. https://meta.discourse.org/t/296544"
        );
        return false;
      } else {
        return true;
      }
    }
  }
}
