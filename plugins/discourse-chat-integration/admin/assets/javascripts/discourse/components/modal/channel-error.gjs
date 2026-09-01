import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const ChannelError = <template>
  <DModal id="chat_integration_error_modal" @closeModal={{@closeModal}}>
    <h4>{{i18n @model.channel.error_key}}</h4>
    <pre>{{@model.channel.error_info}}</pre>
  </DModal>
</template>;

export default ChannelError;
