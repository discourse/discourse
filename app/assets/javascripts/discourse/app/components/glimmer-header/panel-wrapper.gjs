const PanelWrapper = <template>
  {{#if @panelElement}}
    {{#in-element @panelElement}}
      {{yield}}
    {{/in-element}}
  {{/if}}
</template>;

export default PanelWrapper;
