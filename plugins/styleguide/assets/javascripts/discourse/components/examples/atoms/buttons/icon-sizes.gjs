import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    @icon="xmark"
    @translatedTitle="large"
    class="btn-default btn-large"
  />
  <DButton @icon="xmark" @translatedTitle="default" class="btn-default" />
  <DButton
    @icon="xmark"
    @translatedTitle="small"
    class="btn-default btn-small"
  />
</template>
