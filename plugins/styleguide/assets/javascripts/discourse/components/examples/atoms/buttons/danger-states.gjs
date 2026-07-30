import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @icon="trash-can" @translatedLabel="normal" class="btn-danger" />
  <DButton
    @icon="trash-can"
    @translatedLabel="hover"
    class="btn-danger btn-hover"
  />
  <DButton
    @icon="trash-can"
    @translatedLabel="disabled"
    @disabled={{true}}
    class="btn-danger"
  />
</template>
