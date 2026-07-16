import type { TemplateOnlyComponent } from "@ember/component/template-only";
import DInlineFloat from "discourse/float-kit/components/d-inline-float";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";

interface DHeadlessMenuSignature {
  Args: {
    /** The menu instance to render. */
    menu: DMenuInstance;

    /** Whether to render in place instead of into the portal outlet. */
    inline?: boolean | null;
  };
}

/**
 * Renders a menu instance created through the `menu` service, whose trigger
 * lives elsewhere in the DOM rather than being owned by this component. It is
 * mounted once by `DMenus` at the app root, which iterates every registered
 * menu with a detached trigger. Compare `DMenu`, the declarative component that
 * owns both its trigger and its instance.
 */
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
