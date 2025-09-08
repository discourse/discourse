import Service from "@ember/service";

/**
 * Discoure post event API service. Provides methods to refresh the current post calendar.
 *
 * @module PostCalendar
 * @implements {@ember/service}
 */
export default class PostCalendar extends Service {
  registerComponent(component) {
    this.component = component;
  }

  teardownComponent() {
    this.component = null;
  }

  refresh() {
    this.component?.refresh?.();
  }
}
