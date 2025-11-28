import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import ChannelsListStarred from "../../channels-list-starred";
import Navbar from "../navbar";
import ManageStarredButton from "../navbar/manage-starred-button";

export default class ChatRoutesStarredChannels extends Component {
  @service site;

  <template>
    <div class="c-routes --starred-channels">
      <Navbar as |navbar|>
        <navbar.Title @title={{i18n "chat.starred"}} />
        <navbar.Actions as |action|>
          {{#if this.site.mobileView}}
            <action.SearchButton />
          {{/if}}

          <ManageStarredButton />
          <action.OpenDrawerButton />
        </navbar.Actions>
      </Navbar>

      <ChannelsListStarred />
    </div>
  </template>
}
