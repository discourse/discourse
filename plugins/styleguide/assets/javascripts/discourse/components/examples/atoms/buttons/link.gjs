import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @display="link" @icon="trash-can" @translatedLabel="normal" />
  <DButton
    class="btn-hover"
    @display="link"
    @icon="trash-can"
    @translatedLabel="hover"
  />
  <DButton
    @disabled={{true}}
    @display="link"
    @icon="trash-can"
    @translatedLabel="disabled"
  />
</template>
