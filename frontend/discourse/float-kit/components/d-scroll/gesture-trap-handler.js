import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isKeyboardVisible } from "discourse/lib/utilities";

export default class GestureTrapHandler {
  @tracked xTrap = false;
  @tracked yTrap = false;
  @tracked keyboardVisible = false;
  isAtStart = false;
  isAtEnd = false;
  startSpyElement = null;
  endSpyElement = null;
  observer = null;

  constructor(view) {
    this.view = view;
  }

  get needsObserver() {
    const values = this.normalizedTrapValues;
    return values.xStart !== values.xEnd || values.yStart !== values.yEnd;
  }

  getTrapValue(edge, axisKey) {
    const trap = this.view.args.scrollGestureTrap ?? false;

    if (typeof trap === "boolean") {
      return trap;
    }

    if (trap && typeof trap === "object") {
      if (typeof trap[edge] === "boolean") {
        return trap[edge];
      }
      if (typeof trap[axisKey] === "boolean") {
        return trap[axisKey];
      }
    }

    return false;
  }

  get normalizedTrapValues() {
    const xStart = this.getTrapValue("xStart", "x");
    const xEnd = this.getTrapValue("xEnd", "x");
    const yStart = this.getTrapValue("yStart", "y");
    const yEnd = this.getTrapValue("yEnd", "y");

    const axis = this.view.args.axis ?? "y";

    if (axis === "y") {
      const normalizedX = xStart !== xEnd ? true : xStart;
      return { xStart: normalizedX, xEnd: normalizedX, yStart, yEnd };
    } else {
      const normalizedY = yStart !== yEnd ? true : yStart;
      return { xStart, xEnd, yStart: normalizedY, yEnd: normalizedY };
    }
  }

  get swipeTrapIncapable() {
    return this.view.args.pageScroll ?? false;
  }

  get currentTrap() {
    const axis = this.view.args.axis ?? "y";
    return axis === "y" ? this.yTrap : this.xTrap;
  }

  handleIntersection(axis, values, entries) {
    for (const entry of entries) {
      if (entry.target === this.startSpyElement) {
        if (entry.isIntersecting) {
          this.isAtStart = true;
          if (axis === "x") {
            this.xTrap = values.xStart;
          } else {
            this.yTrap = values.yStart;
          }
        } else {
          this.isAtStart = false;
        }
      } else if (entry.target === this.endSpyElement) {
        if (entry.isIntersecting) {
          this.isAtEnd = true;
          if (axis === "x") {
            this.xTrap = values.xEnd;
          } else {
            this.yTrap = values.yEnd;
          }
        } else {
          this.isAtEnd = false;
        }
      }

      if (this.isAtStart && this.isAtEnd) {
        if (axis === "x") {
          this.xTrap = false;
        } else {
          this.yTrap = false;
        }
      }
    }
  }

  @action
  handleResize() {
    const nestedPreventionContainer = this.view.viewElement?.matches(
      '[data-d-scroll~="scroll-container"]:not([data-d-scroll~="swipe-trap-incapable"]) *, [data-d-sheet~="view"] *'
    );
    const nextKeyboardVisible =
      isKeyboardVisible() && !nestedPreventionContainer;
    if (this.keyboardVisible !== nextKeyboardVisible) {
      this.keyboardVisible = nextKeyboardVisible;
    }
  }

  setup() {
    const viewElement = this.view.viewElement;
    const axis = this.view.args.axis ?? "y";
    const values = this.normalizedTrapValues;

    this.xTrap = values.xStart;
    this.yTrap = values.yStart;
    this.handleResize();

    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.handleResize);
    }

    if (!viewElement || !this.needsObserver) {
      return;
    }

    this.observer = new IntersectionObserver(
      this.handleIntersection.bind(this, axis, values),
      {
        root: viewElement,
        rootMargin: "0px",
        threshold: [1],
      }
    );

    if (this.startSpyElement) {
      this.observer.observe(this.startSpyElement);
    }
    if (this.endSpyElement) {
      this.observer.observe(this.endSpyElement);
    }
  }

  registerStartSpy(element) {
    this.startSpyElement = element;
    if (this.observer && element) {
      this.observer.observe(element);
    }
  }

  unregisterStartSpy(element) {
    if (this.observer && element) {
      this.observer.unobserve(element);
    }
    this.startSpyElement = null;
  }

  registerEndSpy(element) {
    this.endSpyElement = element;
    if (this.observer && element) {
      this.observer.observe(element);
    }
  }

  unregisterEndSpy(element) {
    if (this.observer && element) {
      this.observer.unobserve(element);
    }
    this.endSpyElement = null;
  }

  teardown() {
    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.handleResize);
    }

    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }

    if (this.keyboardVisible) {
      this.keyboardVisible = false;
    }
  }

  cleanup() {
    this.teardown();

    this.startSpyElement = null;
    this.endSpyElement = null;
  }
}
