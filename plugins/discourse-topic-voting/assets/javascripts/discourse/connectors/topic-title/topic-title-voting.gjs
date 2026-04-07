import routeAction from "discourse/helpers/route-action";
import VoteBox from "../../components/vote-box";

<template>
  {{#if @outletArgs.model.can_vote}}
    {{#if @outletArgs.model.postStream.loaded}}
      {{#if @outletArgs.model.postStream.firstPostPresent}}
        <div class="voting title-voting">
          <VoteBox
            @topic={{@outletArgs.model}}
            @showLogin={{routeAction "showLogin"}}
          />
        </div>
      {{/if}}
    {{/if}}
  {{/if}}
</template>
