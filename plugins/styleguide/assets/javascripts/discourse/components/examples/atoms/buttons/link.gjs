import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @icon="trash-can" @translatedLabel="normal" @display="link" />
  <DButton
    @icon="trash-can"
    @translatedLabel="hover"
    @display="link"
    class="btn-hover"
  />
  <DButton
    @icon="trash-can"
    @translatedLabel="disabled"
    @display="link"
    @disabled={{true}}
  />
</template>
