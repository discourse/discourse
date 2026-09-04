import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import {
  type DragSource,
  registerDragAndDropSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import WireframeDragSessionService, {
  BlockDragPayload,
} from "../services/wireframe-drag-session";

interface ProxyDragSourcesSignature {
  /** Container chrome whose proxy children become drag sources. */
  Element: HTMLElement;
  /** Modifier arguments. */
  Args: {
    /** Named modifier arguments. */
    Named: {
      /** The outlet the children live in, forwarded in the drag payload. */
      outletName: string;
      /** Structural version used to refresh the registered source set. */
      version: number;
    };
    /** This modifier accepts no positional arguments. */
    Positional: [];
  };
}

/**
 * Makes a container's "proxy" children draggable so they can be reordered on
 * the canvas.
 *
 * Some containers render a stand-in element per child that carries the child's
 * block key in `data-wf-drop-child-key` (e.g. a tabs strip's buttons), instead
 * of rendering each child's own chrome with its drag handle. Those stand-ins
 * aren't drag sources on their own, so this modifier — applied by the editor to
 * a container's chrome — registers a `wf-block` source on each one. Dragging a
 * stand-in then moves its child, landing through the container's normal drop
 * target (the proxy strip), exactly like the block's own handle would.
 *
 * Re-scans whenever `version` changes (pass the editor's structural version) so
 * added / removed children gain / lose a source; every registration is torn
 * down on teardown or before a re-scan. The rendered block stays a pure
 * renderer — the drag-to-reorder behaviour lives here, keyed off the passive
 * `data-wf-drop-child-key` marker.
 */
export default class ProxyDragSourcesModifier extends Modifier<ProxyDragSourcesSignature> {
  /** Tracks the active drag lifecycle. */
  @service declare wireframeDragSession: WireframeDragSessionService;

  /** Cleanup callbacks for each registered proxy drag source. */
  #cleanups: Array<() => void> = [];

  /**
   * Creates the modifier and registers teardown.
   *
   * @param owner - Ember owner creating the modifier.
   * @param args - Initial modifier arguments.
   */
  constructor(owner: Owner, args: ArgsFor<ProxyDragSourcesSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  /**
   * Registers a drag source for each direct proxy child.
   *
   * @param element - Container chrome whose proxies should be scanned.
   * @param _positional - Unused positional arguments.
   * @param named - Outlet identity and structural refresh version.
   */
  modify(
    element: HTMLElement,
    _positional: [],
    { outletName, version }: ProxyDragSourcesSignature["Args"]["Named"]
  ): void {
    // `version` is read purely to re-run on every structural edit, so the
    // source set follows added / removed children.
    void version;
    this.#teardown();
    // Only this chrome's own proxies — a nested container's stand-ins belong to
    // its own chrome (same scoping as the container drop target).
    const proxies = Array.from(
      element.querySelectorAll<HTMLElement>("[data-wf-drop-child-key]")
    ).filter((el) => el.closest(".wireframe-block-chrome") === element);
    for (const proxy of proxies) {
      const blockKey = proxy.dataset.wfDropChildKey;
      this.#cleanups.push(
        registerDragAndDropSource(proxy, () => ({
          type: "wf-block",
          data: { blockKey, outletName },
          onDragStart: ({ source }: { source: DragSource }) =>
            this.wireframeDragSession.startDrag(
              source.data as unknown as BlockDragPayload
            ),
          // `onDragEnd`, not `onDrop`: a drag abandoned over nothing has to
          // clear the session too, and only this one fires for every ending.
          onDragEnd: () => this.wireframeDragSession.endDrag(),
        }))
      );
    }
  }

  /** Clears every proxy drag-source registration. */
  #teardown(): void {
    this.#cleanups.forEach((cleanup) => cleanup());
    this.#cleanups = [];
  }
}
