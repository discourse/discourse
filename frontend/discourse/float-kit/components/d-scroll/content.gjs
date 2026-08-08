import { modifier } from "ember-modifier";
import mergeScrollAttributes from "../../modifiers/merge-scroll-attributes";

const registerContent = modifier((element, [controller]) => {
  controller.registerContent(element);

  return () => controller.unregisterContent(element);
});

const DScrollContent = <template>
  <div
    {{registerContent @controller}}
    ...attributes
    {{mergeScrollAttributes
      "content"
      (if @controller.overflowX "overflow-x" "no-overflow-x")
      (if @controller.overflowY "overflow-y" "no-overflow-y")
      (if @controller.scrollTrapX "trap-x")
      (if @controller.scrollTrapY "trap-y")
    }}
  >
    {{yield}}
  </div>
</template>;

export default DScrollContent;
