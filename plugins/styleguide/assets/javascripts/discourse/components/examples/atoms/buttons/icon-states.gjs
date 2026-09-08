import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-default" @icon="xmark" @translatedTitle="normal" />
  <DButton
    class="btn-default btn-hover"
    @icon="xmark"
    @translatedTitle="hover"
  />
  <DButton
    class="btn-default"
    @disabled={{true}}
    @icon="xmark"
    @translatedTitle="disabled"
  />
</template>
