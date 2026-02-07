import Service, { service } from "@ember/service";

/**
 * Service for managing sheet instances and scroll lock.
 */
export default class SheetRegistry extends Service {
  @service sheetLayerStore;

  /** @type {number} */
  scrollLockCount = 0;

  /** @type {[number, number]} */
  savedScrollPosition = [0, 0];

  /** @type {Function|null} */
  scrollLockCleanup = null;

  /** @type {boolean} */
  isResizing = false;

  /** @type {number|null} */
  resizeTimeout = null;

  /** @type {Set<string>} */
  controllersWithScrollLock = new Set();

  /**
   * Cleans up all listeners and state when the service is destroyed.
   */
  willDestroy() {
    super.willDestroy();

    this.sheetLayerStore.cleanupInert();
    if (this.scrollLockCleanup) {
      this.scrollLockCleanup();
      this.scrollLockCleanup = null;
    }
    this.scrollLockCount = 0;
  }

  /**
   * Registers a sheet controller with the registry.
   *
   * @param {Object} controller
   */
  register(controller) {
    this.sheetLayerStore.registerSheet(controller);
    this.sheetLayerStore.syncLayerFromSheet(controller);

    if (controller.inertOutside) {
      this.applyScrollLock();
      this.controllersWithScrollLock.add(controller.id);
    }

    this.sheetLayerStore.recalculateInertOutside();
  }

  /**
   * Unregisters a sheet controller from the registry.
   *
   * @param {Object} controller
   */
  unregister(controller) {
    if (this.controllersWithScrollLock.has(controller.id)) {
      this.removeScrollLock();
      this.controllersWithScrollLock.delete(controller.id);
    }

    this.sheetLayerStore.unregisterSheet(controller.id);
    this.sheetLayerStore.recalculateInertOutside();
  }

  /**
   * Updates scroll lock for a controller.
   *
   * @param {Object} controller
   * @param {boolean} shouldLock
   */
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

  /**
   * Notifies registry that a sheet's inertOutside state changed.
   *
   * @param {Object} controller
   * @param {boolean} inertOutside
   */
  updateInertOutside(controller, inertOutside) {
    this.updateScrollLock(controller, inertOutside);

    if (controller.view) {
      if (inertOutside) {
        controller.view.setAttribute("aria-modal", "true");
      } else {
        controller.view.removeAttribute("aria-modal");
      }
    }

    this.sheetLayerStore.updateSheet(controller);
    this.sheetLayerStore.syncLayerFromSheet(controller);
    this.sheetLayerStore.recalculateInertOutside();
  }

  /**
   * Applies scroll lock with reference counting.
   */
  applyScrollLock() {
    if (this.scrollLockCount === 0) {
      this.savedScrollPosition = [window.scrollX, window.scrollY];
      document.documentElement.style.setProperty("overflow", "hidden");

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

  /**
   * Removes scroll lock with reference counting.
   */
  removeScrollLock() {
    if (this.scrollLockCount > 0) {
      this.scrollLockCount--;
      if (this.scrollLockCount === 0) {
        document.documentElement.style.removeProperty("overflow");
        if (this.scrollLockCleanup) {
          this.scrollLockCleanup();
          this.scrollLockCleanup = null;
        }
      }
    }
  }
}
