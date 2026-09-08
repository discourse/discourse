import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import ChatSkeleton from "../chat-skeleton.gjs";

let loaded;

export default class LazyChatChannel extends Component {
  get module() {
    return (loaded ??= import("../chat-channel.gjs"));
  }

  <template>
    <DAsyncContent @asyncData={{this.module}}>
      <:loading><ChatSkeleton /></:loading>
      <:content as |module|>
        <module.default
          @channel={{@channel}}
          @context={{@context}}
          @disableAutoFocus={{@disableAutoFocus}}
          @disableKeystrokeCapture={{@disableKeystrokeCapture}}
          @hiddenMessageIds={{@hiddenMessageIds}}
          @isFiltering={{@isFiltering}}
          @onToggleFilter={{@onToggleFilter}}
          @targetMessageId={{@targetMessageId}}
        />
      </:content>
    </DAsyncContent>
  </template>
}
