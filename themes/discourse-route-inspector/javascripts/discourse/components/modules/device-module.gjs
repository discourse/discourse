import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DataSection from "../data-section";

export default class DeviceModule extends Component {
  @service capabilities;

  get rawData() {
    return {
      isAndroid: this.capabilities.isAndroid,
      isWinphone: this.capabilities.isWinphone,
      isIpadOS: this.capabilities.isIpadOS,
      isIOS: this.capabilities.isIOS,
      isApple: this.capabilities.isApple,
      isOpera: this.capabilities.isOpera,
      isFirefox: this.capabilities.isFirefox,
      isChrome: this.capabilities.isChrome,
      isSafari: this.capabilities.isSafari,
      isMobileDevice: this.capabilities.isMobileDevice,
      touch: this.capabilities.touch,
      hasContactPicker: this.capabilities.hasContactPicker,
      canVibrate: this.capabilities.canVibrate,
      isPwa: this.capabilities.isPwa,
      isiOSPWA: this.capabilities.isiOSPWA,
      wasLaunchedFromDiscourseHub:
        this.capabilities.wasLaunchedFromDiscourseHub,
      isAppWebview: this.capabilities.isAppWebview,
      userHasBeenActive: this.capabilities.userHasBeenActive,
      supportsServiceWorker: this.capabilities.supportsServiceWorker,
    };
  }

  <template>
    <DataSection
      @sectionKey="capabilities.device"
      @label={{i18n (themePrefix "route_inspector.device")}}
      @icon="lucide-smartphone"
      @rawData={{this.rawData}}
      @tableKey="device"
      @isSectionCollapsed={{@isSectionCollapsed}}
      @onToggleSection={{@onToggleSection}}
      @onDrillInto={{@onDrillInto}}
    />
  </template>
}
