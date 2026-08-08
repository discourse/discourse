import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @icon="xmark" @translatedTitle="normal" class="btn-default" />
  <DButton
    @icon="xmark"
    @translatedTitle="hover"
    class="btn-default btn-hover"
  />
  <DButton
    @icon="xmark"
    @translatedTitle="disabled"
    @disabled={{true}}
    class="btn-default"
  />
</template>
