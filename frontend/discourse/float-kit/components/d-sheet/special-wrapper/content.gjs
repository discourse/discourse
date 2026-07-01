const DSheetSpecialWrapperContent = <template>
  <div data-d-sheet="scroll-trap-stabilizer" ...attributes>
    {{yield}}
  </div>
</template>;

export default DSheetSpecialWrapperContent;
