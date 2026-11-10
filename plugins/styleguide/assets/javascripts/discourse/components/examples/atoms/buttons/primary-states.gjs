import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-primary" @icon="plus" @translatedLabel="normal" />
  <DButton
    class="btn-primary btn-hover"
    @icon="plus"
    @translatedLabel="hover"
  />
  <DButton
    class="btn-primary"
    @disabled={{true}}
    @icon="plus"
    @translatedLabel="disabled"
  />
</template>
