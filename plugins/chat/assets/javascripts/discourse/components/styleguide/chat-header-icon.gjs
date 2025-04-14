import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
  HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
} from "discourse/plugins/chat/discourse/controllers/preferences-chat";

export default class ChatStyleguideChatHeaderIcon extends Component {
  @tracked isActive = false;
  @tracked currentUserInDnD = false;
  @tracked urgentCount;
  @tracked unreadCount;
  @tracked indicatorPreference = HEADER_INDICATOR_PREFERENCE_ALL_NEW;

  get indicatorPreferences() {
    return [
      HEADER_INDICATOR_PREFERENCE_ALL_NEW,
      HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
      HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
      HEADER_INDICATOR_PREFERENCE_NEVER,
    ];
  }

  @action
  toggleIsActive() {
    this.isActive = !this.isActive;
  }

  @action
  toggleCurrentUserInDnD() {
    this.currentUserInDnD = !this.currentUserInDnD;
  }

  @action
  updateUnreadCount(event) {
    this.unreadCount = event.target.value;
  }

  @action
  updateUrgentCount(event) {
    this.urgentCount = event.target.value;
  }

  @action
  updateIndicatorPreference(value) {
    this.indicatorPreference = value;
  }
}

<StyleguideExample @title="<Chat::Header::Icon>">
  <Styleguide::Component>
    <header
      class="d-header"
      style="display: flex; align-items: center; justify-content: center;"
    >
      <ul class="d-header-icons">
        <li class="header-dropdown-toggle chat-header-icon">
          <Chat::Header::Icon
            @isActive={{this.isActive}}
            @currentUserInDnD={{this.currentUserInDnD}}
            @unreadCount={{this.unreadCount}}
            @urgentCount={{this.urgentCount}}
            @indicatorPreference={{this.indicatorPreference}}
          />
        </li>
      </ul>
    </header>
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="isActive">
      <DToggleSwitch
        @state={{this.isActive}}
        {{on "click" this.toggleIsActive}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="currentUserInDnD">
      <DToggleSwitch
        @state={{this.currentUserInDnD}}
        {{on "click" this.toggleCurrentUserInDnD}}
      />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
  <Styleguide::Controls::Row @name="Unread count">
    <input
      type="number"
      {{on "input" this.updateUnreadCount}}
      value={{this.unreadCount}}
    />
  </Styleguide::Controls::Row>
  <Styleguide::Controls::Row @name="Urgent count">
    <input
      type="number"
      {{on "input" this.updateUrgentCount}}
      value={{this.urgentCount}}
    />
  </Styleguide::Controls::Row>
  <Styleguide::Controls::Row @name="Indicator preference">
    <ComboBox
      @value={{this.indicatorPreference}}
      @content={{this.indicatorPreferences}}
      @onChange={{this.updateIndicatorPreference}}
      @valueProperty={{null}}
      @nameProperty={{null}}
    />

  </Styleguide::Controls::Row>
</StyleguideExample>