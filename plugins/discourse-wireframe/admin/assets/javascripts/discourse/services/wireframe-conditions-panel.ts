import type Owner from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import Service from "@ember/service";

const STORAGE_KEY = "wireframe.conditions-panel";

/** Persisted position and size of the floating conditions panel. */
export interface ConditionsPanelRect {
  /** Panel height in pixels. */
  height: number;
  /** Panel width in pixels. */
  width: number;
  /** Horizontal viewport position in pixels. */
  x: number;
  /** Vertical viewport position in pixels. */
  y: number;
}

/**
 * Holds the condition-builder floating panel's UI state: whether it's detached
 * from the inspector into a free-floating panel, and its on-screen rect. Both
 * are a user PREFERENCE persisted to localStorage so they survive reloads —
 * not session state (they are not reset on editor exit).
 *
 * A dependency-free peer service: it injects nothing and is read/commanded
 * through the orchestrator's thin facades, so the condition-panel chrome stays
 * decoupled from the rest of the editor.
 */
export default class WireframeConditionsPanelService extends Service {
  /**
   * The panel preference. `detached` is whether the condition builder floats
   * free of the inspector; `rect` is its last on-screen position/size (or
   * `null` before the user has moved it). Held in a `#`-private tracked object
   * so the getters stay reactive without exposing the mutable state.
   */
  #state: {
    /** Whether the panel floats independently of the inspector. */
    detached: boolean;
    /** Last persisted panel geometry. */
    rect: ConditionsPanelRect | null;
  } = trackedObject({
    detached: false,
    rect: null,
  });

  /**
   * Creates the service and restores the persisted panel preference.
   *
   * @param owner - Ember owner used to initialize the service.
   */
  constructor(owner: Owner) {
    super(owner);
    this.#load();
  }

  /**
   * Whether the condition builder is detached into a floating panel.
   *
   */
  get detached(): boolean {
    return this.#state.detached;
  }

  /**
   * The floating panel's last position/size, or `null` if it hasn't been moved.
   * A frozen copy so consumers can read/spread it without mutating service
   * state.
   *
   */
  get rect(): Readonly<ConditionsPanelRect> | null {
    return this.#state.rect ? Object.freeze({ ...this.#state.rect }) : null;
  }

  /**
   * Collapses the floating panel back into the inspector.
   */
  close(): void {
    this.#state.detached = false;
    this.#persist();
  }

  /**
   * Toggles the panel between docked (in the inspector) and detached (floating).
   */
  toggleDetached(): void {
    this.#state.detached = !this.#state.detached;
    this.#persist();
  }

  /**
   * Records the floating panel's new position/size after a drag/resize.
   *
   * @param rect - New viewport position and dimensions.
   */
  updateRect(rect: ConditionsPanelRect): void {
    this.#state.rect = rect;
    this.#persist();
  }

  /**
   * Hydrates the panel preference from localStorage on construction. Tolerates
   * missing / malformed entries by leaving the defaults in place.
   */
  #load(): void {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        return;
      }
      // TODO(devxp-typescript-pending): replace this storage boundary cast
      // when the persisted panel state has a shared runtime validator.
      const parsed = JSON.parse(raw) as {
        /** Persisted detached state, when present. */
        detached?: boolean;
        /** Persisted panel geometry, when present. */
        rect?: ConditionsPanelRect | null;
      };
      if (typeof parsed?.detached === "boolean") {
        this.#state.detached = parsed.detached;
      }
      if (parsed?.rect && typeof parsed.rect === "object") {
        this.#state.rect = parsed.rect;
      }
    } catch {
      // Corrupt JSON in localStorage — ignore, keep defaults.
    }
  }

  /** Persists the current panel preference when browser storage is available. */
  #persist(): void {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          detached: this.#state.detached,
          rect: this.#state.rect,
        })
      );
    } catch {
      // QuotaExceeded / disabled storage — non-fatal, the preference
      // just won't survive the session.
    }
  }
}
