import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    @icon="trash-can"
    @translatedLabel="large"
    class="btn-danger btn-large"
  />
  <DButton @icon="trash-can" @translatedLabel="default" class="btn-danger" />
  <DButton
    @icon="trash-can"
    @translatedLabel="small"
    class="btn-danger btn-small"
  />
</template>
