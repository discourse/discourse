import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type { ComponentLike } from "@glint/template";
import {
  type BlockImageValue,
  imageComposition,
} from "discourse/blocks/image-value";
import FKControlInputUntyped from "discourse/form-kit/components/fk/control/input";
import noop from "discourse/helpers/noop";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ImagePositionPicker, {
  type PercentagePosition,
} from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-position-picker";
import InspectorSegmentedField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-segmented-field";
import WireframeImageCompositionService, {
  ImageEditTarget,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-composition";

/** TODO(devxp-typescript-pending): remove when the input exports a signature. */
const FKControlInput = FKControlInputUntyped as unknown as ComponentLike<{
  Args: {
    type: "number";
    after: string;
    field: {
      hasExplicitType: boolean;
      value: string | number;
      set: () => void;
    };
  };
  Element: HTMLInputElement;
}>;

interface ImageCompositionControlsSignature {
  Args: {
    /** Stable image argument being edited. */
    target: ImageEditTarget;
    /** Persisted image value, excluding temporary previews. */
    value: BlockImageValue;
    /** Called after a canvas adjustment starts. */
    onReposition?: () => void;
    /** Shows only fit and canvas repositioning in the quick-action popup. */
    compact?: boolean;
  };
}

export default class ImageCompositionControls extends Component<ImageCompositionControlsSignature> {
  @service declare wireframeImageComposition: WireframeImageCompositionService;

  @tracked _zoomDraft: string | null = null;

  willDestroy(): void {
    if (
      this.wireframeImageComposition.matches(this.args.target) &&
      !this.wireframeImageComposition.repositioning
    ) {
      this.wireframeImageComposition.cancel();
    }
    super.willDestroy();
  }

  get composition() {
    return this.wireframeImageComposition.matches(this.args.target)
      ? (this.wireframeImageComposition.draft ??
          imageComposition(this.args.value))
      : imageComposition(this.args.value);
  }

  get fitOptions() {
    return [
      { value: "cover", label: i18n("wireframe.inspector.image.fill") },
      { value: "contain", label: i18n("wireframe.inspector.image.fit") },
    ];
  }

  get zoomValue(): string | number {
    return this._zoomDraft ?? this.composition.zoom;
  }

  @action
  cancel(): void {
    this._zoomDraft = null;
    this.wireframeImageComposition.cancel();
  }

  @action
  changeFit(fit: string): void {
    if (fit === "cover" || fit === "contain") {
      this.wireframeImageComposition.change(this.args.target, { fit });
    }
  }

  @action
  changePosition(position: PercentagePosition): void {
    this.wireframeImageComposition.change(this.args.target, { position });
  }

  @action
  keyDown(event: KeyboardEvent): void {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.cancel();
    } else if (event.key === "Enter") {
      event.preventDefault();
      this.zoom(true, event);
    }
  }

  @action
  previewPosition(position: PercentagePosition): void {
    this.wireframeImageComposition.preview(this.args.target, { position });
  }

  @action
  reposition(): void {
    this.wireframeImageComposition.begin(this.args.target, true);
    this.args.onReposition?.();
  }

  @action
  reset(): void {
    this.wireframeImageComposition.change(this.args.target, imageComposition());
  }

  @action
  zoom(commit: boolean, event: Event): void {
    const input = event.currentTarget;
    if (!(input instanceof HTMLInputElement)) {
      return;
    }
    this._zoomDraft = !commit && input.type === "number" ? input.value : null;
    if (!Number.isFinite(input.valueAsNumber)) {
      if (commit) {
        input.value = String(this.composition.zoom);
      }
      return;
    }
    const patch = { zoom: input.valueAsNumber };
    if (commit) {
      this.wireframeImageComposition.change(this.args.target, patch);
    } else {
      this.wireframeImageComposition.preview(this.args.target, patch);
    }
  }

  <template>
    <fieldset
      class={{dConcatClass
        "wireframe-image-composition"
        (if @compact "--compact")
      }}
    >
      <legend
        class={{dConcatClass
          "wireframe-image-composition__heading"
          (if @compact "sr-only")
        }}
      >
        <span class="wireframe-image-composition__heading-content">
          <span>{{i18n "wireframe.inspector.image.composition"}}</span>
          {{#unless @compact}}
            <DButton
              class="btn-transparent btn-small"
              @action={{this.reset}}
              @label="wireframe.inspector.image.reset_composition"
            />
          {{/unless}}
        </span>
      </legend>
      <div class="wireframe-image-composition__fit">
        <span>{{i18n "wireframe.inspector.image.fit"}}</span>
        <InspectorSegmentedField
          @items={{this.fitOptions}}
          @onChange={{this.changeFit}}
          @value={{this.composition.fit}}
        />
      </div>
      {{#unless @compact}}
        <div class="wireframe-image-composition__position">
          <span>{{i18n "wireframe.position_picker.label"}}</span>
          <ImagePositionPicker
            @onCancel={{this.cancel}}
            @onChange={{this.changePosition}}
            @onPreview={{this.previewPosition}}
            @value={{this.composition.position}}
          />
        </div>
        <div class="wireframe-image-composition__zoom">
          <span>{{i18n "wireframe.inspector.image.zoom_short"}}</span>
          {{! Native events retain raw drafts and the preview/commit boundaries. }}
          <FKControlInput
            aria-label={{i18n "wireframe.inspector.image.zoom"}}
            max="250"
            min="100"
            step="1"
            @after="%"
            @field={{hash hasExplicitType=true value=this.zoomValue set=(noop)}}
            @type="number"
            {{on "input" (fn this.zoom false)}}
            {{on "blur" (fn this.zoom true)}}
            {{on "keydown" this.keyDown}}
          />
          <input
            aria-label={{i18n "wireframe.inspector.image.zoom"}}
            max="250"
            min="100"
            step="1"
            type="range"
            value={{this.composition.zoom}}
            {{on "input" (fn this.zoom false)}}
            {{on "change" (fn this.zoom true)}}
            {{on "keydown" this.keyDown}}
          />
        </div>
      {{/unless}}
      <div class="wireframe-image-composition__actions">
        <DButton
          class={{if
            @compact
            "wireframe-image-editor-menu__action"
            "btn-default"
          }}
          @action={{this.reposition}}
          @label={{if
            @compact
            "wireframe.inspector.image.reposition_short"
            "wireframe.inspector.image.reposition"
          }}
        />
      </div>
    </fieldset>
  </template>
}
