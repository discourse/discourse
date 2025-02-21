import concatClass from "discourse/helpers/concat-class";
import DInlineFloat from "float-kit/components/d-inline-float";

const DHeadlessMenu = <template>
  <DInlineFloat
    @instance={{@menu}}
    @trapTab={{@menu.options.trapTab}}
    @mainClass={{concatClass
      "fk-d-menu"
      (if @menu.options.insideComposer "-inside-composer")
    }}
    @innerClass="fk-d-menu__inner-content"
    @role="dialog"
    @inline={{@inline}}
  />
</template>;

export default DHeadlessMenu;
