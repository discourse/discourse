import { and, or } from "discourse/truth-helpers";
import VoteBox from "../../components/vote-box";

<template>
  {{#let @outletArgs.model as |topic|}}
    {{#if
      (and
        topic.can_vote
        (or
          topic.is_nested_view
          (and topic.postStream.loaded topic.postStream.firstPostPresent)
        )
      )
    }}
      <div class="voting title-voting">
        <VoteBox @topic={{topic}} />
      </div>
    {{/if}}
  {{/let}}
</template>
