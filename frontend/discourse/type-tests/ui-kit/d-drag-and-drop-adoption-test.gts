// Positive template invocations for native drag adoption, asserting the target
// and auto-scroll Signatures resolve together. Keep this file free of Glint
// directives: one expected error would suppress unrelated declaration failures.
import { hash } from "@ember/helper";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropTarget, {
  type NativeDragAdoptionFeedback,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

declare const noop: () => void;
declare function matchesLink(feedback: NativeDragAdoptionFeedback): boolean;
declare function linkData(
  feedback: NativeDragAdoptionFeedback
): Record<string, unknown>;

const Positives = <template>
  {{! An element target can adopt browser-started page content by predicate }}
  <div
    {{dDragAndDropTarget
      adopts=(hash type="web-link" match=matchesLink getData=linkData)
      onDrop=noop
    }}
  ></div>

  {{! Registered and adopted source vocabularies can coexist on one target }}
  <div
    {{dDragAndDropTarget
      accepts="card"
      adopts=(hash type="web-link" match=matchesLink)
      onDrop=noop
    }}
  ></div>

  {{! Auto-scroll sees the adoption's declared type like any element drag }}
  <div {{dDragAndDropAutoScroll types="web-link"}}></div>
</template>;

export default Positives;
