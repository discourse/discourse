import { Input } from "@ember/component";

const Text = <template>
  <div ...attributes>
    <Input
      class="wizard-container__text-input"
      id={{@field.id}}
      placeholder={{@field.placeholder}}
      tabindex="9"
      @value={{@field.value}}
    />
  </div>
</template>;

export default Text;
