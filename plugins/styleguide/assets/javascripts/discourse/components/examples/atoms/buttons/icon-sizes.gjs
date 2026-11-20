import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="btn-default btn-large"
    @icon="xmark"
    @translatedTitle="large"
  />
  <DButton class="btn-default" @icon="xmark" @translatedTitle="default" />
  <DButton
    class="btn-default btn-small"
    @icon="xmark"
    @translatedTitle="small"
  />
</template>
