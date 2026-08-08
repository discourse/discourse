import Service, { service } from "@ember/service";

export default class SheetRegistry extends Service {
  @service sheetLayerStore;

  scrollLockCount = 0;
  savedScrollPosition = [0, 0];
  scrollLockCleanup = null;
  isResizing = false;
  resizeTimeout = null;
  controllersWithScrollLock = new Set();

  willDestroy() {
    super.willDestroy();

    this.sheetLayerStore.cleanupInert();
    if (this.scrollLockCleanup) {
      this.scrollLockCleanup();
      this.scrollLockCleanup = null;
    }
    this.scrollLockCount = 0;
  }

  register(controller) {
    if (this.sheetLayerStore.hasSheet(controller)) {
      return;
    }

    this.sheetLayerStore.registerSheet(controller);

    if (controller.inertOutside) {
      this.applyScrollLock();
      this.controllersWithScrollLock.add(controller.id);
      controller.view?.setAttribute("aria-modal", "true");
    }

    this.sheetLayerStore.recalculateInertOutside();
  }

  unregister(controller) {
    controller.view?.removeAttribute("aria-modal");

    if (!this.sheetLayerStore.hasSheet(controller)) {
      return;
    }

    if (this.controllersWithScrollLock.has(controller.id)) {
      this.removeScrollLock();
      this.controllersWithScrollLock.delete(controller.id);
    }

    this.sheetLayerStore.unregisterSheet(controller.id);
    this.sheetLayerStore.recalculateInertOutside();
  }

  updateScrollLock(controller, shouldLock) {
    const hasLock = this.controllersWithScrollLock.has(controller.id);

    if (shouldLock && !hasLock) {
      this.applyScrollLock();
      this.controllersWithScrollLock.add(controller.id);
    } else if (!shouldLock && hasLock) {
      this.removeScrollLock();
      this.controllersWithScrollLock.delete(controller.id);
    }
  }

  updateInertOutside(controller, inertOutside) {
    if (!this.sheetLayerStore.hasSheet(controller)) {
      return;
    }

    this.updateScrollLock(controller, inertOutside);

    if (controller.view) {
      if (inertOutside) {
        controller.view.setAttribute("aria-modal", "true");
      } else {
        controller.view.removeAttribute("aria-modal");
      }
    }

    this.sheetLayerStore.recalculateInertOutside();
  }

  applyScrollLock() {
    if (this.scrollLockCount === 0) {
      this.savedScrollPosition = [window.scrollX, window.scrollY];
      document.body.style.setProperty("overflow", "hidden");

      const handleResize = () => {
        clearTimeout(this.resizeTimeout);
        this.isResizing = true;
        this.resizeTimeout = setTimeout(() => {
          this.isResizing = false;
        }, 50);
      };

      const handleScroll = () => {
        if (!this.isResizing) {
          window.scrollTo(...this.savedScrollPosition);
        }
      };

      window.addEventListener("resize", handleResize);
      window.addEventListener("scroll", handleScroll, { passive: false });

      this.scrollLockCleanup = () => {
        window.removeEventListener("resize", handleResize);
        window.removeEventListener("scroll", handleScroll);
        if (this.resizeTimeout) {
          clearTimeout(this.resizeTimeout);
          this.resizeTimeout = null;
        }
      };
    }
    this.scrollLockCount++;
  }

  removeScrollLock() {
    if (this.scrollLockCount > 0) {
      this.scrollLockCount--;
      if (this.scrollLockCount === 0) {
        document.body.style.removeProperty("overflow");
        if (this.scrollLockCleanup) {
          this.scrollLockCleanup();
          this.scrollLockCleanup = null;
        }
      }
    }
  }
}
