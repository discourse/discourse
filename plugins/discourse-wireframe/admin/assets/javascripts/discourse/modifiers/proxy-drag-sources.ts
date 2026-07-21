import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import { registerDragAndDropSource } from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import type WireframeDragSessionService from "../services/wireframe-drag-session";

interface ProxyDragSourcesSignature {
  Element: HTMLElement;
  Args: {
    Named: {
      // The outlet the children live in (for the drag payload).
      outletName: string;
      // A value that changes on every structural edit; read only to re-run
      // this modifier so the source set tracks the current children.
      version: number;
    };
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
  @service declare wireframeDragSession: WireframeDragSessionService;

  #cleanups: Array<() => void> = [];

  constructor(owner: Owner, args: ArgsFor<ProxyDragSourcesSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  modify(
    element: HTMLElement,
    _positional: [],
    { outletName, version }: ProxyDragSourcesSignature["Args"]["Named"]
  ) {
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
          onDragStart: ({
            source,
          }: {
            source: { data: { blockKey: string; outletName: string } };
          }) => this.wireframeDragSession.startDrag(source.data),
          onDrop: () => this.wireframeDragSession.endDrag(),
        }))
      );
    }
  }

  #teardown() {
    this.#cleanups.forEach((cleanup) => cleanup());
    this.#cleanups = [];
  }
}
