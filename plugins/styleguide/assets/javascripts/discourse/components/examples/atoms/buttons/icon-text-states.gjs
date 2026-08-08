import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @icon="plus" @translatedLabel="normal" class="btn-default" />
  <DButton
    @icon="plus"
    @translatedLabel="hover"
    class="btn-default btn-hover"
  />
  <DButton
    @icon="plus"
    @translatedLabel="disabled"
    @disabled={{true}}
    class="btn-default"
  />
</template>
