import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";

export default class VoiceGlobalCallLayer extends Component {
  @service voiceWebrtc;

  @action
  async loadCallUI() {
    if (!this.voiceWebrtc.activeRoomId) {
      return null;
    }

    return await import("./call-ui");
  }

  <template>
    <DAsyncContent @asyncData={{this.loadCallUI}}>
      <:loading></:loading>
      <:empty></:empty>
      <:content as |ui|>
        <ui.VoiceCanvas />
        <ui.CallWidget />
      </:content>
    </DAsyncContent>
  </template>
}
