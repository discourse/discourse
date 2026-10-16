import LiveCallButton from "../../components/live/call-button.gjs";

const LiveProfileCallButton = <template>
  {{#if @outletArgs.model.live_can_call}}
    <li class="live-call-button">
      <LiveCallButton @user={{@outletArgs.model}} />
    </li>
  {{/if}}
</template>;

export default LiveProfileCallButton;
