import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    @icon="plus"
    @translatedLabel="large"
    class="btn-default btn-large"
  />
  <DButton @icon="plus" @translatedLabel="default" class="btn-default" />
  <DButton
    @icon="plus"
    @translatedLabel="small"
    class="btn-default btn-small"
  />
</template>
