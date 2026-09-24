import dIcon from "discourse/ui-kit/helpers/d-icon";

const SettingValidationMessage = <template>
  <div ...attributes>
    <div class="validation-error {{unless @message 'hidden'}}">
      {{dIcon "xmark"}}
      {{@message}}
    </div>
  </div>
</template>;

export default SettingValidationMessage;
