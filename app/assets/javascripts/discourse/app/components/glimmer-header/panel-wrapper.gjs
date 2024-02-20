import ConditionalInElement from "../conditional-in-element";

const PanelWrapper = <template>
  <ConditionalInElement @element={{@panelElement}}>
    {{yield}}
  </ConditionalInElement>
</template>;

export default PanelWrapper;
