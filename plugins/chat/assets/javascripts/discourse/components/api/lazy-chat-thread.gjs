import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import ChatSkeleton from "../chat-skeleton.gjs";

let loaded;

export default class LazyChatThread extends Component {
  get module() {
    return (loaded ??= import("../chat-thread.gjs"));
  }

  <template>
    <DAsyncContent @asyncData={{this.module}}>
      <:loading><ChatSkeleton /></:loading>
      <:content as |module|>
        <module.default
          @channel={{@channel}}
          @targetMessageId={{@targetMessageId}}
          @thread={{@thread}}
        />
      </:content>
    </DAsyncContent>
  </template>
}
