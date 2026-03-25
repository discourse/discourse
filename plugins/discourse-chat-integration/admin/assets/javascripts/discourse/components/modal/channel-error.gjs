import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const ChannelError = <template>
  <DModal @closeModal={{@closeModal}} id="chat_integration_error_modal">
    <h4>{{i18n @model.channel.error_key}}</h4>
    <pre>{{@model.channel.error_info}}</pre>
  </DModal>
</template>;

export default ChannelError;
