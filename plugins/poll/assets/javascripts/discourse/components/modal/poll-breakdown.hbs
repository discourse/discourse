{{! template-lint-disable no-invalid-interactive }}
<DModal
  @title={{i18n "poll.breakdown.title"}}
  @closeModal={{@closeModal}}
  class="poll-breakdown has-tabs"
>
  <:headerBelowTitle>
    <ul class="modal-tabs">
      <li
        class={{concat-class
          "modal-tab percentage"
          (if (eq this.displayMode "percentage") "is-active")
        }}
        {{on "click" (fn (mut this.displayMode) "percentage")}}
      >{{i18n "poll.breakdown.percentage"}}</li>
      <li
        class={{concat-class
          "modal-tab count"
          (if (eq this.displayMode "count") "is-active")
        }}
        {{on "click" (fn (mut this.displayMode) "count")}}
      >{{i18n "poll.breakdown.count"}}</li>
    </ul>
  </:headerBelowTitle>
  <:body>
    <div class="poll-breakdown-sidebar">
      <p class="poll-breakdown-title">
        {{this.title}}
      </p>

      <div class="poll-breakdown-total-votes">{{i18n
          "poll.breakdown.votes"
          count=this.model.poll.voters
        }}</div>

      <ul class="poll-breakdown-options">
        {{#each this.model.poll.options as |option index|}}
          <PollBreakdownOption
            @option={{option}}
            @index={{index}}
            @totalVotes={{this.totalVotes}}
            @optionsCount={{this.model.poll.options.length}}
            @displayMode={{this.displayMode}}
            @highlightedOption={{this.highlightedOption}}
            @onMouseOver={{fn (mut this.highlightedOption) index}}
            @onMouseOut={{fn (mut this.highlightedOption) null}}
          />
        {{/each}}
      </ul>
    </div>

    <div class="poll-breakdown-body">
      <div class="poll-breakdown-body-header">
        <label class="poll-breakdown-body-header-label">{{i18n
            "poll.breakdown.breakdown"
          }}</label>

        <ComboBox
          @content={{this.groupableUserFields}}
          @value={{this.groupedBy}}
          @nameProperty="label"
          @onChange={{this.setGrouping}}
          class="poll-breakdown-dropdown"
        />
      </div>

      <div class="poll-breakdown-charts">
        {{#each this.charts as |chart|}}
          <PollBreakdownChart
            @group={{get chart "group"}}
            @options={{get chart "options"}}
            @displayMode={{this.displayMode}}
            @highlightedOption={{this.highlightedOption}}
            @setHighlightedOption={{fn (mut this.highlightedOption)}}
          />
        {{/each}}
      </div>
    </div>
  </:body>
</DModal>