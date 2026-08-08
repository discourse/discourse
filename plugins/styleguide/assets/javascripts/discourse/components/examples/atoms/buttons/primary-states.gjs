import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @icon="plus" @translatedLabel="normal" class="btn-primary" />
  <DButton
    @icon="plus"
    @translatedLabel="hover"
    class="btn-primary btn-hover"
  />
  <DButton
    @icon="plus"
    @translatedLabel="disabled"
    @disabled={{true}}
    class="btn-primary"
  />
</template>
