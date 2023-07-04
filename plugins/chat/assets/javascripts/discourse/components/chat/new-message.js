import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
export default class ChatNewMessage extends Component {
  @service("chat-api") api;
  @service("chat-channel-composer") composer;
  @service chat;

  @tracked channel;
}
