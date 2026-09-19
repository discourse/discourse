import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-flat" @icon="trash-can" @translatedLabel="normal" />
  <DButton
    class="btn-flat btn-hover"
    @icon="trash-can"
    @translatedLabel="hover"
  />
  <DButton
    class="btn-flat"
    @disabled={{true}}
    @icon="trash-can"
    @translatedLabel="disabled"
  />
</template>
