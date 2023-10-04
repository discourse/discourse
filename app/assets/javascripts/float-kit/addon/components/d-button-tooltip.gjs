const DButtonTooltip = <template>
  <div class="fk-d-button-tooltip" ...attributes>
    {{yield to="button"}}
    {{yield to="tooltip"}}
  </div>
</template>;

export default DButtonTooltip;
