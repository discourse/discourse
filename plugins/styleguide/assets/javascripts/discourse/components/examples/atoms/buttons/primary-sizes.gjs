import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="btn-primary btn-large"
    @icon="plus"
    @translatedLabel="large"
  />
  <DButton class="btn-primary" @icon="plus" @translatedLabel="default" />
  <DButton
    class="btn-primary btn-small"
    @icon="plus"
    @translatedLabel="small"
  />
</template>
