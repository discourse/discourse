import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    @icon="plus"
    @translatedLabel="large"
    class="btn-primary btn-large"
  />
  <DButton @icon="plus" @translatedLabel="default" class="btn-primary" />
  <DButton
    @icon="plus"
    @translatedLabel="small"
    class="btn-primary btn-small"
  />
</template>
