import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import effect from "discourse/float-kit/helpers/effect";
import concatClass from "discourse/helpers/concat-class";
import { capabilities } from "discourse/services/capabilities";
import Outlet from "./outlet";

const DEFAULT_BACKDROP_TRAVEL_ANIMATION = {
  opacity: ({ progress }) => Math.min(progress * 0.33, 0.33),
};

export default class Backdrop extends Component {
  @service themeColorManager;

  @tracked backdropElement = null;

  _themeColorDimmingAlpha = 0;

  get swipeable() {
    return this.args.swipeable ?? true;
  }

  get effectiveThemeColorDimming() {
    const dimming = this.args.themeColorDimming ?? false;
    if (dimming === "auto") {
      return (
        capabilities.isWebKit && !capabilities.isStandaloneWithBlackTranslucent
      );
    }
    return Boolean(dimming);
  }

  get effectiveTravelAnimation() {
    const userAnimation = this.args.travelAnimation;

    if (userAnimation === null) {
      return null;
    }

    const merged = { ...DEFAULT_BACKDROP_TRAVEL_ANIMATION, ...userAnimation };

    if (Array.isArray(merged.opacity)) {
      const [start, end] = merged.opacity;
      merged.opacity = ({ progress }) => start + (end - start) * progress;
    }

    return merged;
  }

  get shouldUseThemeColorDimmingOverlay() {
    return (
      this.effectiveThemeColorDimming &&
      this.args.sheet?.state.longRunning.isActive &&
      typeof this.effectiveTravelAnimation?.opacity === "function"
    );
  }

  get outletTravelAnimation() {
    if (this.shouldUseThemeColorDimmingOverlay) {
      return { ...this.effectiveTravelAnimation, opacity: "ignore" };
    }
    return this.effectiveTravelAnimation;
  }

  @action
  setBackdropElement(element) {
    this.backdropElement = element;
  }

  @action
  syncBackdrop(sheet, backdropElement, swipeable) {
    if (!sheet || !backdropElement) {
      return;
    }

    sheet.registerBackdrop(backdropElement, swipeable);

    return () => {
      sheet.unregisterBackdrop(backdropElement);
    };
  }

  @action
  syncThemeColorDimming(
    sheet,
    backdropElement,
    shouldUseThemeColorDimmingOverlay,
    travelAnimation
  ) {
    if (!sheet || !backdropElement || !shouldUseThemeColorDimmingOverlay) {
      return;
    }

    const opacityFn = travelAnimation?.opacity;
    if (typeof opacityFn !== "function") {
      return;
    }

    if (!this.themeColorManager.getAndStoreUnderlyingThemeColorAsRGBArray()) {
      return;
    }

    const dimmingOverlayId = sheet.themeColorAdapter.dimmingOverlayId;
    const backgroundColor =
      window.getComputedStyle(backdropElement).backgroundColor || "rgb(0,0,0)";

    const overlay = this.themeColorManager.updateThemeColorDimmingOverlay({
      abortRemoval: true,
      dimmingOverlayId,
      color: backgroundColor,
      alpha: this._themeColorDimmingAlpha,
    });

    const unregisterTravelAnimation = sheet.registerTravelAnimation({
      callback: (progress) => {
        const opacity = opacityFn({ progress });
        this._themeColorDimmingAlpha = opacity;
        backdropElement.style.setProperty("opacity", opacity);
        this.themeColorManager.updateThemeColorDimmingOverlayAlphaValue(
          overlay,
          opacity
        );
      },
    });

    return () => {
      unregisterTravelAnimation?.();
      this.themeColorManager.removeThemeColorDimmingOverlay(dimmingOverlayId);
      this._themeColorDimmingAlpha = 0;
    };
  }

  <template>
    {{#if @sheet}}
      {{effect this.syncBackdrop @sheet this.backdropElement this.swipeable}}
      {{effect
        this.syncThemeColorDimming
        @sheet
        this.backdropElement
        this.shouldUseThemeColorDimmingOverlay
        this.effectiveTravelAnimation
      }}
      <Outlet
        @sheet={{@sheet}}
        @travelAnimation={{this.outletTravelAnimation}}
        @stackingAnimation={{@stackingAnimation}}
        data-d-sheet={{concatClass
          "backdrop"
          (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
        }}
        {{didInsert this.setBackdropElement}}
        ...attributes
      />
    {{/if}}
  </template>
}
