import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { boundedImageNumber } from "discourse/blocks/image-value";
import DButton from "discourse/ui-kit/d-button";
import dPointerDrag, {
  type DPointerDragInfo,
} from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";
import WireframeImageCompositionService, {
  ImageEditTarget,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-composition";

interface ImageRepositionSignature {
  Args: {
    /** Stable image argument being adjusted. */
    target: ImageEditTarget;
    /** The clipping frame in the canvas. */
    frame: HTMLElement;
    /** Positioned chrome containing the frame. */
    chrome: HTMLElement;
  };
}

export default class ImageReposition extends Component<ImageRepositionSignature> {
  @service declare wireframeImageComposition: WireframeImageCompositionService;

  #gesture: { x: number; y: number; travelX: number; travelY: number } | null =
    null;

  willDestroy(): void {
    if (this.wireframeImageComposition.matches(this.args.target)) {
      this.wireframeImageComposition.cancel();
    }
    super.willDestroy();
  }

  get style() {
    const frame = this.args.frame.getBoundingClientRect();
    const chrome = this.args.chrome.getBoundingClientRect();
    return trustHTML(
      `top: ${frame.top - chrome.top}px; left: ${frame.left - chrome.left}px; width: ${frame.width}px; height: ${frame.height}px;`
    );
  }

  @action
  cancel(): void {
    this.wireframeImageComposition.cancel();
  }

  @action
  cancelGesture(): void {
    if (this.#gesture) {
      this.wireframeImageComposition.preview(this.args.target, {
        position: { x: this.#gesture.x, y: this.#gesture.y },
      });
      this.#gesture = null;
    }
  }

  @action
  done(): void {
    this.wireframeImageComposition.commit();
  }

  @action
  drag(_event: PointerEvent, info: DPointerDragInfo): void {
    const gesture = this.#gesture;
    if (gesture) {
      this.wireframeImageComposition.preview(this.args.target, {
        position: {
          x: boundedImageNumber(
            gesture.x +
              (Math.abs(gesture.travelX) > 0.5
                ? (info.delta.x / gesture.travelX) * 100
                : 0),
            0,
            100,
            50
          ),
          y: boundedImageNumber(
            gesture.y +
              (Math.abs(gesture.travelY) > 0.5
                ? (info.delta.y / gesture.travelY) * 100
                : 0),
            0,
            100,
            50
          ),
        },
      });
    }
  }

  @action
  focus(element: HTMLElement): void {
    element.focus();
  }

  @action
  keyDown(event: KeyboardEvent): void {
    if (event.key === "Escape") {
      this.stop(event);
      this.cancel();
      return;
    }
    const position = this.wireframeImageComposition.draft?.position;
    if (!position || !event.key.startsWith("Arrow")) {
      return;
    }
    this.stop(event);
    const step = event.shiftKey ? 10 : 1;
    this.wireframeImageComposition.preview(this.args.target, {
      position: {
        x:
          position.x +
          (event.key === "ArrowRight"
            ? step
            : event.key === "ArrowLeft"
              ? -step
              : 0),
        y:
          position.y +
          (event.key === "ArrowDown"
            ? step
            : event.key === "ArrowUp"
              ? -step
              : 0),
      },
    });
  }

  @action
  start(): boolean {
    const draft = this.wireframeImageComposition.draft;
    const image = this.args.frame.querySelector("img");
    if (!draft || !image?.naturalWidth || !image.naturalHeight) {
      return false;
    }
    const frame = this.args.frame.getBoundingClientRect();
    const ratio =
      ((draft.fit === "cover" ? Math.max : Math.min)(
        frame.width / image.naturalWidth,
        frame.height / image.naturalHeight
      ) *
        draft.zoom) /
      100;
    this.#gesture = {
      ...draft.position,
      travelX: frame.width - image.naturalWidth * ratio,
      travelY: frame.height - image.naturalHeight * ratio,
    };
    return true;
  }

  @action
  stop(event: Event): void {
    event.preventDefault();
    event.stopPropagation();
  }

  <template>
    <div class="wireframe-image-reposition" style={{this.style}}>
      <button
        type="button"
        class="wireframe-image-reposition__surface"
        aria-label={{i18n "wireframe.inspector.image.reposition_help"}}
        {{didInsert this.focus}}
        {{on "click" this.stop}}
        {{on "keydown" this.keyDown}}
        {{dPointerDrag
          onDragStart=this.start
          onDrag=this.drag
          onDragEnd=this.drag
          onDragCancel=this.cancelGesture
          stopPropagation=true
        }}
      ></button>
      <div class="wireframe-image-reposition__actions">
        <DButton class="btn-primary" @label="done" @action={{this.done}} />
        <DButton class="btn-default" @label="cancel" @action={{this.cancel}} />
      </div>
    </div>
  </template>
}
