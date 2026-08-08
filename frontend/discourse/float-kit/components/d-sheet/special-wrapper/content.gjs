import mergeSheetAttributes from "../../../modifiers/merge-sheet-attributes";

const DSheetSpecialWrapperContent = <template>
  <div ...attributes {{mergeSheetAttributes "scroll-trap-stabilizer"}}>
    {{yield}}
  </div>
</template>;

export default DSheetSpecialWrapperContent;
