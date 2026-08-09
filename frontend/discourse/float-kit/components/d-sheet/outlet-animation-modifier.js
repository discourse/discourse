import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { createTweenFunction } from "./animation";
import { normalizeOutletAnimationConfig } from "./outlet-animation-config";

export default class OutletAnimationModifier extends Modifier {
  #animatedProperties = new Set();
  #cleanupFns = [];
  #element = null;
  #ownedInlineStyles = new Map();
  #sheet = null;
  #stackingAnimation = null;
  #stackingStaticStyles = new Map();
  #stackingStylesActive = false;
  #stackOutlet = false;
  #travelAnimation = null;
  #travelStaticStyles = new Map();
  #travelStylesActive = false;
  #willChangeProperties = new Set();

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#cleanup());
  }

  modify(
    element,
    [sheet, travelAnimation, stackingAnimation],
    { stackOutlet = false }
  ) {
    const travelStylesActive = Boolean(
      !stackOutlet && sheet?.state?.longRunning?.isActive
    );
    const stackingStylesActive = this.#getStackingCount(sheet) >= 1;
    const targetChanged = element !== this.#element || sheet !== this.#sheet;
    const configurationChanged =
      targetChanged ||
      travelAnimation !== this.#travelAnimation ||
      stackingAnimation !== this.#stackingAnimation ||
      stackOutlet !== this.#stackOutlet;
    const lifecycleChanged =
      travelStylesActive !== this.#travelStylesActive ||
      stackingStylesActive !== this.#stackingStylesActive;

    if (!configurationChanged && !lifecycleChanged) {
      return;
    }

    if (targetChanged) {
      this.#cleanup(this.#element);
    } else if (configurationChanged) {
      this.#unregisterAnimations();
      this.#resetAnimationConfiguration();
    }

    this.#element = element;
    this.#sheet = sheet;
    this.#travelAnimation = travelAnimation;
    this.#stackingAnimation = stackingAnimation;
    this.#stackOutlet = stackOutlet;
    this.#travelStylesActive = travelStylesActive;
    this.#stackingStylesActive = stackingStylesActive;

    if (!sheet) {
      return;
    }

    if (configurationChanged) {
      this.#registerAnimation(element, sheet, travelAnimation, "travel");
      this.#registerAnimation(element, sheet, stackingAnimation, "stacking");
    }

    this.#restoreNonAnimatedInlineStyles(element);
    this.#applyLifecycleStyles(element);
  }

  #getStackingCount(sheet) {
    const stackId = sheet?.stackId;

    if (!stackId) {
      return 0;
    }

    return sheet.sheetStackRegistry?.stackingCounts.get(stackId) ?? 0;
  }

  #registerAnimation(element, sheet, animationConfig, type) {
    if (!animationConfig) {
      return;
    }

    const {
      animatedProperties,
      staticStyles,
      styleTemplates,
      templates,
      willChangeProperties,
    } = normalizeOutletAnimationConfig(animationConfig);

    if (type === "travel") {
      this.#travelStaticStyles = staticStyles;
    } else {
      this.#stackingStaticStyles = staticStyles;
    }

    for (const property of willChangeProperties) {
      this.#willChangeProperties.add(property);
    }
    for (const property of animatedProperties) {
      this.#animatedProperties.add(property);
    }

    const registerMethod =
      type === "travel"
        ? "registerTravelAnimation"
        : "registerStackingAnimation";

    const unregister = sheet[registerMethod]({
      target: element,
      config: animationConfig,
      animatedProperties,
      templates,
      callback: this.#createAnimationCallback(element, styleTemplates),
      persistStyle: (property, value) => {
        this.#writeInlineStyle(element, property, value);
      },
      restorePersistedStyles: () => {
        this.#restorePersistedStyles(element, animatedProperties);
      },
    });

    this.#cleanupFns.push(unregister);
  }

  #applyLifecycleStyles(element) {
    if (this.#travelStylesActive) {
      this.#applyStaticStyles(element, this.#travelStaticStyles);
    }

    if (this.#stackingStylesActive) {
      this.#applyStaticStyles(element, this.#stackingStaticStyles);
    }

    const willChangeActive = this.#stackOutlet
      ? this.#stackingStylesActive
      : this.#travelStylesActive;

    if (willChangeActive && this.#willChangeProperties.size) {
      const { value: originalWillChange } = this.#rememberInlineStyle(
        element,
        "will-change"
      );
      const animationWillChange = [...this.#willChangeProperties].join(", ");
      const willChange = originalWillChange
        ? `${animationWillChange}, ${originalWillChange}`
        : animationWillChange;

      this.#writeInlineStyle(element, "will-change", willChange);
    }
  }

  #applyStaticStyles(element, staticStyles) {
    for (const [prop, value] of staticStyles) {
      this.#writeInlineStyle(element, prop, value);
    }
  }

  #rememberInlineStyle(element, property) {
    let originalStyle = this.#ownedInlineStyles.get(property);
    const currentPriority = element.style.getPropertyPriority(property);
    const currentValue = element.style.getPropertyValue(property);

    if (!originalStyle) {
      originalStyle = {
        priority: currentPriority,
        value: currentValue,
      };
      this.#ownedInlineStyles.set(property, originalStyle);
    } else if (
      currentPriority !== originalStyle.lastWrittenPriority ||
      currentValue !== originalStyle.lastWrittenValue
    ) {
      originalStyle.priority = currentPriority;
      originalStyle.value = currentValue;
    }

    return originalStyle;
  }

  #writeInlineStyle(element, property, value) {
    const inlineStyle = this.#rememberInlineStyle(element, property);

    element.style.setProperty(property, value);
    inlineStyle.lastWrittenPriority =
      element.style.getPropertyPriority(property);
    inlineStyle.lastWrittenValue = element.style.getPropertyValue(property);
  }

  #createAnimationCallback(element, styleTemplates) {
    const len = styleTemplates.length;

    return (progress, tween) => {
      const tweenFn = tween || createTweenFunction(progress);
      const params = { progress, tween: tweenFn };

      for (let i = 0; i < len; i++) {
        const [property, animationFunction] = styleTemplates[i];
        this.#writeInlineStyle(element, property, animationFunction(params));
      }
    };
  }

  #unregisterAnimations() {
    for (const fn of this.#cleanupFns) {
      fn?.();
    }
    this.#cleanupFns = [];
  }

  #restoreNonAnimatedInlineStyles(element) {
    if (element) {
      for (const [property, inlineStyle] of this.#ownedInlineStyles) {
        if (this.#animatedProperties.has(property)) {
          continue;
        }

        this.#restoreInlineStyle(element, property, inlineStyle);
        this.#ownedInlineStyles.delete(property);
      }
    }
  }

  #restorePersistedStyles(element, animatedProperties) {
    if (!element) {
      return;
    }

    for (const property of animatedProperties) {
      const inlineStyle = this.#ownedInlineStyles.get(property);
      if (!inlineStyle) {
        continue;
      }

      this.#restoreInlineStyle(element, property, inlineStyle);
      this.#ownedInlineStyles.delete(property);
    }

    this.#reapplyActiveStaticStyles(element, animatedProperties);
  }

  #restoreInlineStyle(
    element,
    property,
    { lastWrittenPriority, lastWrittenValue, priority, value }
  ) {
    if (
      element.style.getPropertyPriority(property) !== lastWrittenPriority ||
      element.style.getPropertyValue(property) !== lastWrittenValue
    ) {
      return;
    }

    if (value) {
      element.style.setProperty(property, value, priority);
    } else {
      element.style.removeProperty(property);
    }
  }

  #reapplyActiveStaticStyles(element, properties) {
    const travelStylesActive = Boolean(
      !this.#stackOutlet && this.#sheet?.state?.longRunning?.isActive
    );
    const stackingStylesActive = this.#getStackingCount(this.#sheet) >= 1;

    for (const property of properties) {
      if (travelStylesActive && this.#travelStaticStyles.has(property)) {
        this.#writeInlineStyle(
          element,
          property,
          this.#travelStaticStyles.get(property)
        );
      }

      if (stackingStylesActive && this.#stackingStaticStyles.has(property)) {
        this.#writeInlineStyle(
          element,
          property,
          this.#stackingStaticStyles.get(property)
        );
      }
    }
  }

  #restoreAllInlineStyles(element) {
    if (element) {
      for (const [property, inlineStyle] of this.#ownedInlineStyles) {
        this.#restoreInlineStyle(element, property, inlineStyle);
      }
    }

    this.#ownedInlineStyles.clear();
  }

  #resetAnimationConfiguration() {
    this.#travelStaticStyles = new Map();
    this.#stackingStaticStyles = new Map();
    this.#animatedProperties.clear();
    this.#willChangeProperties.clear();
  }

  #cleanup(element = this.#element) {
    this.#unregisterAnimations();
    this.#restoreAllInlineStyles(element);
    this.#resetAnimationConfiguration();
    this.#element = null;
    this.#sheet = null;
    this.#travelAnimation = null;
    this.#stackingAnimation = null;
    this.#stackOutlet = false;
    this.#travelStylesActive = false;
    this.#stackingStylesActive = false;
  }
}
