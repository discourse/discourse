import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="btn-default btn-large"
    @icon="plus"
    @translatedLabel="large"
  />
  <DButton class="btn-default" @icon="plus" @translatedLabel="default" />
  <DButton
    class="btn-default btn-small"
    @icon="plus"
    @translatedLabel="small"
  />
</template>
