import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-default" @icon="plus" @translatedLabel="normal" />
  <DButton
    class="btn-default btn-hover"
    @icon="plus"
    @translatedLabel="hover"
  />
  <DButton
    class="btn-default"
    @disabled={{true}}
    @icon="plus"
    @translatedLabel="disabled"
  />
</template>
