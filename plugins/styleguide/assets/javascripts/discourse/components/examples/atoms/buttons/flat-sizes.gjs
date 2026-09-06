import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    @icon="trash-can"
    @translatedTitle="large"
    class="btn-flat btn-large"
  />
  <DButton @icon="trash-can" @translatedTitle="default" class="btn-flat" />
  <DButton
    @icon="trash-can"
    @translatedTitle="small"
    class="btn-flat btn-small"
  />
</template>
