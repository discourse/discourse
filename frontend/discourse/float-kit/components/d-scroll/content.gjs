import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";

const DScrollContent = <template>
  <div
    data-d-scroll={{concatClass
      "content"
      (if @controller.overflowX "overflow-x" "no-overflow-x")
      (if @controller.overflowY "overflow-y" "no-overflow-y")
      (if @controller.trapX "trap-x")
      (if @controller.trapY "trap-y")
    }}
    {{didInsert @controller.registerContent}}
    ...attributes
  >
    {{yield}}
  </div>
</template>;

export default DScrollContent;
