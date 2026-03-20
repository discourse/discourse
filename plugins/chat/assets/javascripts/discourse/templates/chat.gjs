import bodyClass from "discourse/helpers/body-class";
import htmlClass from "discourse/helpers/html-class";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ChannelsList from "discourse/plugins/chat/discourse/components/channels-list";
import ChatFooter from "discourse/plugins/chat/discourse/components/chat-footer";

export default <template>
  {{bodyClass "has-chat" "has-full-page-chat"}}
  {{htmlClass "has-chat" "has-full-page-chat"}}

  <div id="chat-progress-bar-container"></div>

  <div
    class={{dConcatClass
      "full-page-chat"
      (if @controller.shouldUseCoreSidebar "full-page-chat-sidebar-enabled")
    }}
  >
    {{#if @controller.shouldUseChatSidebar}}
      <ChannelsList />
    {{/if}}

    <div
      id="main-chat-outlet"
      class={{dConcatClass
        "main-chat-outlet"
        @controller.mainOutletModifierClasses
      }}
    >
      {{outlet}}
      {{#if @controller.shouldUseChatFooter}}
        <ChatFooter />
      {{/if}}
    </div>
  </div>
</template>
