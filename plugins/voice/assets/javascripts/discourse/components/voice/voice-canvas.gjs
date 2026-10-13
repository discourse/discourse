import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";

export default class VoiceVoiceCanvas extends Component {
  @service voiceWebrtc;

  get localStream() {
    return this.voiceWebrtc.localStream;
  }

  get remoteStreams() {
    return this.voiceWebrtc.remoteStreams;
  }

  get remoteScreenAudioStreams() {
    return this.voiceWebrtc.remoteScreenAudioStreams;
  }

  <template>
    <section class="voice-voice-canvas">
      {{#if this.localStream}}
        <audio
          autoplay
          muted
          playsinline
          {{didInsert (fn this.voiceWebrtc.attachStream this.localStream)}}
          {{didUpdate
            (fn this.voiceWebrtc.attachStream this.localStream)
            this.localStream
          }}
        />
      {{/if}}

      {{#each this.remoteStreams key="id" as |stream|}}
        <audio
          autoplay
          playsinline
          {{didInsert (fn this.voiceWebrtc.attachStream stream)}}
          {{didUpdate (fn this.voiceWebrtc.attachStream stream) stream}}
        />
      {{/each}}

      {{#each this.remoteScreenAudioStreams key="id" as |stream|}}
        <audio
          autoplay
          playsinline
          {{didInsert (fn this.voiceWebrtc.attachStream stream)}}
          {{didUpdate (fn this.voiceWebrtc.attachStream stream) stream}}
        />
      {{/each}}
    </section>
  </template>
}
