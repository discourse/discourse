import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-danger" @icon="trash-can" @translatedLabel="normal" />
  <DButton
    class="btn-danger btn-hover"
    @icon="trash-can"
    @translatedLabel="hover"
  />
  <DButton
    class="btn-danger"
    @disabled={{true}}
    @icon="trash-can"
    @translatedLabel="disabled"
  />
</template>
