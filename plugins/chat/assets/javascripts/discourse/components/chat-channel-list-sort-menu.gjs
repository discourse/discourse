import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";
import ChatChannelListSortChoice, {
  SORT_OPTIONS,
} from "./chat-channel-list-sort-choice";

export default <template>
  <DDropdownMenu
    aria-label={{i18n "chat.channel_list.sort.title"}}
    class="chat-channel-list-sort-menu"
    role="group"
    ...attributes
    as |dropdown|
  >
    <dropdown.subheader role="presentation">
      {{i18n "chat.channel_list.sort.title"}}
    </dropdown.subheader>

    {{#each SORT_OPTIONS as |choice|}}
      <ChatChannelListSortChoice
        @choice={{choice}}
        @close={{@close}}
        @closeParent={{@closeParent}}
        @closeSubmenu={{@closeSubmenu}}
        @section={{@section}}
      />
    {{/each}}
  </DDropdownMenu>
</template>
