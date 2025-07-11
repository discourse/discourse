import { concat, get } from "@ember/helper";
import { i18n } from "discourse-i18n";

const ChannelData = <template>
  {{#each @provider.channel_parameters as |param|}}
    {{#unless param.hidden}}
      <div class="channel-info">
        <span class="field-name">
          {{i18n
            (concat
              "chat_integration.provider."
              @channel.provider
              ".param."
              param.key
              ".title"
            )
          }}:
        </span>
        <span class="field-value">{{get @channel.data param.key}}</span>
        <br />
      </div>
    {{/unless}}
  {{/each}}
</template>;

export default ChannelData;
