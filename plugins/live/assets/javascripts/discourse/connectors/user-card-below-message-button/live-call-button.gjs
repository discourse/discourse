import LiveCallButton from "../../components/live/call-button.gjs";

const LiveCardCallButton = <template>
  {{#if @outletArgs.user.live_can_call}}
    <li class="user-card-below-message-button live-call-button">
      <LiveCallButton @user={{@outletArgs.user}} />
    </li>
  {{/if}}
</template>;

export default LiveCardCallButton;
