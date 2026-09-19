import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton
    class="btn-transparent"
    @icon="trash-can"
    @translatedLabel="normal"
  />
  <DButton
    class="btn-transparent btn-hover"
    @icon="trash-can"
    @translatedLabel="hover"
  />
  <DButton
    class="btn-transparent"
    @disabled={{true}}
    @icon="trash-can"
    @translatedLabel="disabled"
  />
</template>
