import type { TemplateOnlyComponent } from "@ember/component/template-only";
import DInlineFloat from "discourse/float-kit/components/d-inline-float";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";

interface DHeadlessMenuSignature {
  Args: {
    menu: DMenuInstance;
    inline?: boolean | null;
  };
}

const DHeadlessMenu: TemplateOnlyComponent<DHeadlessMenuSignature> = <template>
  <DInlineFloat
    @instance={{@menu}}
    @trapTab={{@menu.options.trapTab}}
    @mainClass="fk-d-menu"
    @innerClass="fk-d-menu__inner-content"
    @role="dialog"
    @inline={{@inline}}
  />
</template>;

export default DHeadlessMenu;
