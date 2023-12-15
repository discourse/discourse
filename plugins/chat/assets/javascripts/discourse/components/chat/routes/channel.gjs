import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import SidePanel from "discourse/plugins/chat/discourse/components/chat-side-panel";
import FullPageChat from "discourse/plugins/chat/discourse/components/full-page-chat";
import Navbar from "discourse/plugins/chat/discourse/components/navbar";

export default class ChatRoutesChannel extends Component {
  @service site;

  <template>
    <div class="c-routes-channel">
      <Navbar as |navbar|>
        {{#if this.site.mobileView}}
          <navbar.BackButton />
        {{/if}}
        <navbar.ChannelTitle @channel={{@channel}} />
        <navbar.Actions as |action|>
          <action.OpenDrawerButton />
          <action.ThreadsListButton @channel={{@channel}} />
        </navbar.Actions>
      </Navbar>

      <FullPageChat
        @channel={{@channel}}
        @targetMessageId={{@targetMessageId}}
      />
    </div>

    <SidePanel>
      {{outlet}}
    </SidePanel>
  </template>
}
