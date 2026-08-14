import { runInDebug } from "@ember/debug";

export default class RovingFocusDiagnostics {
  #warnedWindowedTypeAhead = false;
  #warnedUndetectedSecondAxis = false;
  #warnedNoIndicator = false;
  #warnedUnreachableActiveDescendant = false;

  warnWindowedTypeAhead(): void {
    runInDebug(() => {
      if (this.#warnedWindowedTypeAhead) {
        return;
      }
      this.#warnedWindowedTypeAhead = true;
      // eslint-disable-next-line no-console
      console.warn(
        `dRovingFocus: typeAhead is declined because logicalCount exceeds the mounted rows. A ` +
          `search over part of the set answers with a nearer match while a truer one sits ` +
          `off-window. Search the full data from the consumer instead.`
      );
    });
  }

  warnMissingFocusIndicator(hasIndicator: boolean): void {
    if (hasIndicator) {
      return;
    }
    runInDebug(() => {
      if (this.#warnedNoIndicator) {
        return;
      }
      this.#warnedNoIndicator = true;
      // eslint-disable-next-line no-console
      console.warn(
        `dRovingFocus: focusStrategy="active-descendant" with neither activeClass nor onActiveChange, so ` +
          `nothing marks the active item and the cursor is invisible. Pass activeClass, or ` +
          `render the highlight yourself from onActiveChange.`
      );
    });
  }

  warnUndetectedSecondAxis(style: CSSStyleDeclaration): void {
    const wrappingFlex =
      (style.display === "flex" || style.display === "inline-flex") &&
      style.flexWrap.startsWith("wrap");
    const multiColumn = Number(style.columnCount) > 1;
    if (!wrappingFlex && !multiColumn) {
      return;
    }
    runInDebug(() => {
      if (this.#warnedUndetectedSecondAxis) {
        return;
      }
      this.#warnedUndetectedSecondAxis = true;
      // eslint-disable-next-line no-console
      console.warn(
        `dRovingFocus: orientation="grid" on a ${
          wrappingFlex ? "wrapping flex" : "multi-column"
        } container, which publishes no column track list, so the group navigates on one axis. ` +
          `Lay it out with CSS grid to get the second axis.`
      );
    });
  }

  warnUnreachableActiveDescendant(
    controller: HTMLElement | null,
    target: HTMLElement
  ): void {
    if (!controller || this.#isReachable(controller, target)) {
      return;
    }
    runInDebug(() => {
      if (this.#warnedUnreachableActiveDescendant) {
        return;
      }
      this.#warnedUnreachableActiveDescendant = true;
      // eslint-disable-next-line no-console
      console.warn(
        `dRovingFocus: the controller points aria-activedescendant at an item it does not ` +
          `contain, does not aria-own, and does not reach through aria-controls, which ARIA ` +
          `does not permit. Assistive technology will not follow the cursor. Put the items ` +
          `inside the controller, or add aria-owns, or give a combobox/textbox/searchbox ` +
          `controller an aria-controls pointing at the list.`
      );
    });
  }

  #isReachable(controller: HTMLElement, target: HTMLElement): boolean {
    if (controller.contains(target)) {
      return true;
    }
    if (this.#ariaIds(controller, "aria-owns").includes(target.id)) {
      return true;
    }
    const role = controller.getAttribute("role");
    const textual = role
      ? role === "combobox" || role === "textbox" || role === "searchbox"
      : controller instanceof HTMLInputElement ||
        controller instanceof HTMLTextAreaElement;
    if (!textual) {
      return false;
    }
    const document = controller.ownerDocument;
    return this.#ariaIds(controller, "aria-controls").some((id) => {
      const controlled = document.getElementById(id);
      return (
        !!controlled &&
        (controlled.contains(target) ||
          this.#ariaIds(controlled, "aria-owns").includes(target.id))
      );
    });
  }

  #ariaIds(element: HTMLElement, attribute: string): string[] {
    return (element.getAttribute(attribute) ?? "").split(/\s+/).filter(Boolean);
  }
}
