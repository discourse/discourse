import DInlineFloat from "float-kit/components/d-inline-float";

const DHeadlessMenu = <template>
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
