import ConditionalInElement from "../conditional-in-element";

const PanelPortal = <template>
  <ConditionalInElement @element={{@panelElement}}>
    {{yield}}
  </ConditionalInElement>
</template>;

export default PanelPortal;
