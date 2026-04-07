import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import VoteBox from "../../components/vote-box";

const siteSettings = service();

<template>
  {{#if siteSettings.topic_voting_show_vote_in_topic_list}}
    {{#if @outletArgs.topic.can_vote}}
      <div class="voting list-voting">
        <VoteBox
          @topic={{@outletArgs.topic}}
          @showLogin={{routeAction "showLogin"}}
        />
      </div>
    {{/if}}
  {{/if}}
</template>
