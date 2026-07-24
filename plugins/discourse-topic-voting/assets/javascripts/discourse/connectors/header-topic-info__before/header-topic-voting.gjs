import VoteBox from "../../components/vote-box";

export default <template>
  {{#if @outletArgs.topic.can_vote}}
    <div class="voting header-title-voting">
      <VoteBox @topic={{@outletArgs.topic}} />
    </div>
  {{/if}}
</template>
