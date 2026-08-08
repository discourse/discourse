import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { capabilities } from "discourse/services/capabilities";
import mergeSheetAttributes from "../../modifiers/merge-sheet-attributes";
import Outlet from "./outlet";

const DEFAULT_BACKDROP_TRAVEL_ANIMATION = {
  opacity: ({ progress }) => Math.min(progress * 0.33, 0.33),
};
const UNSET = Symbol("unset");

export default class Backdrop extends Component {
  @service themeColorManager;

  syncBackdrop = modifier((backdropElement, [sheet, swipeable]) => {
    if (!sheet) {
      return;
    }

    sheet.registerBackdrop(backdropElement, swipeable);

    return () => {
      sheet.unregisterBackdrop(backdropElement);
    };
  });
  syncThemeColorDimming = modifier(
    (
      backdropElement,
      [sheet, shouldUseThemeColorDimmingOverlay, travelAnimation]
    ) => {
      if (!sheet || !shouldUseThemeColorDimmingOverlay) {
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
        window.getComputedStyle(backdropElement).backgroundColor ||
        "rgb(0,0,0)";

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
      };
    }
  );
  #travelAnimationInput = UNSET;
  #effectiveTravelAnimation;
  #outletTravelAnimationInput = UNSET;
  #outletThemeColorDimming;
  #outletTravelAnimation;
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
    return this.#resolveEffectiveTravelAnimation(this.args.travelAnimation);
  }

  #resolveEffectiveTravelAnimation(userAnimation) {
    if (userAnimation === this.#travelAnimationInput) {
      return this.#effectiveTravelAnimation;
    }

    const merged = { ...DEFAULT_BACKDROP_TRAVEL_ANIMATION, ...userAnimation };

    if (Array.isArray(merged.opacity)) {
      const [start, end] = merged.opacity;
      merged.opacity = ({ progress }) => start + (end - start) * progress;
    }

    this.#travelAnimationInput = userAnimation;
    this.#effectiveTravelAnimation = merged;

    return this.#effectiveTravelAnimation;
  }

  get shouldUseThemeColorDimmingOverlay() {
    return (
      this.effectiveThemeColorDimming &&
      this.args.sheet?.state.longRunning.isActive &&
      typeof this.effectiveTravelAnimation?.opacity === "function"
    );
  }

  get outletTravelAnimation() {
    const travelAnimation = this.effectiveTravelAnimation;
    const useThemeColorDimming = this.shouldUseThemeColorDimmingOverlay;

    return this.#resolveOutletTravelAnimation(
      travelAnimation,
      useThemeColorDimming
    );
  }

  #resolveOutletTravelAnimation(travelAnimation, useThemeColorDimming) {
    if (
      travelAnimation === this.#outletTravelAnimationInput &&
      useThemeColorDimming === this.#outletThemeColorDimming
    ) {
      return this.#outletTravelAnimation;
    }

    this.#outletTravelAnimationInput = travelAnimation;
    this.#outletThemeColorDimming = useThemeColorDimming;
    this.#outletTravelAnimation = useThemeColorDimming
      ? { ...travelAnimation, opacity: "ignore" }
      : travelAnimation;

    return this.#outletTravelAnimation;
  }

  <template>
    {{#if @sheet}}
      <Outlet
        @sheet={{@sheet}}
        @travelAnimation={{this.outletTravelAnimation}}
        @stackingAnimation={{@stackingAnimation}}
        {{this.syncBackdrop @sheet this.swipeable}}
        {{this.syncThemeColorDimming
          @sheet
          this.shouldUseThemeColorDimmingOverlay
          this.effectiveTravelAnimation
        }}
        ...attributes
        {{mergeSheetAttributes
          "backdrop"
          (if @sheet.scrollContainerShouldBePassThrough "no-pointer-events")
        }}
      >
        {{yield}}
      </Outlet>
    {{/if}}
  </template>
}
