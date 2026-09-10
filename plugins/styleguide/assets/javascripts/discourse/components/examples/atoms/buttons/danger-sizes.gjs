import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="btn-danger btn-large"
    @icon="trash-can"
    @translatedLabel="large"
  />
  <DButton class="btn-danger" @icon="trash-can" @translatedLabel="default" />
  <DButton
    class="btn-danger btn-small"
    @icon="trash-can"
    @translatedLabel="small"
  />
</template>
