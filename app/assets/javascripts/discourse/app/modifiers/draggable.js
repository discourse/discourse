import Modifier from "ember-modifier";
import drag from "discourse-common/lib/drag";

export default class DraggableModifier extends Modifier {
  modify(el, _, { didStartDrag, didEndDrag }) {
    drag(el, didStartDrag, didEndDrag);
  }
}
