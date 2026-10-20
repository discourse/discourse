import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";

export default class LiveVoiceCanvas extends Component {
  @service liveWebrtc;

  get localStream() {
    return this.liveWebrtc.localStream;
  }

  get remoteStreams() {
    return this.liveWebrtc.remoteStreams;
  }

  get remoteScreenAudioStreams() {
    return this.liveWebrtc.remoteScreenAudioStreams;
  }

  <template>
    <section class="live-voice-canvas">
      {{#if this.localStream}}
        <audio
          autoplay
          muted
          playsinline
          {{didInsert (fn this.liveWebrtc.attachStream this.localStream)}}
          {{didUpdate
            (fn this.liveWebrtc.attachStream this.localStream)
            this.localStream
          }}
        />
      {{/if}}

      {{#each this.remoteStreams key="id" as |stream|}}
        <audio
          autoplay
          playsinline
          {{didInsert (fn this.liveWebrtc.attachStream stream)}}
          {{didUpdate (fn this.liveWebrtc.attachStream stream) stream}}
        />
      {{/each}}

      {{#each this.remoteScreenAudioStreams key="id" as |stream|}}
        <audio
          autoplay
          playsinline
          {{didInsert (fn this.liveWebrtc.attachStream stream)}}
          {{didUpdate (fn this.liveWebrtc.attachStream stream) stream}}
        />
      {{/each}}
    </section>
  </template>
}
