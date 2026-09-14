import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="btn-flat btn-large"
    @icon="trash-can"
    @translatedTitle="large"
  />
  <DButton class="btn-flat" @icon="trash-can" @translatedTitle="default" />
  <DButton
    class="btn-flat btn-small"
    @icon="trash-can"
    @translatedTitle="small"
  />
</template>
