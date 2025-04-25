<div class="select-kit-header-wrapper">
  {{#each this.icons as |icon|}}
    {{d-icon icon}}
  {{/each}}

  {{#if this.selectKit.options.useHeaderFilter}}
    <div class="select-kit-header--filter">
      {{#if this.selectedContent.length}}
        {{#each this.selectedContent as |item|}}
          {{component
            this.selectKit.options.selectedChoiceComponent
            item=item
            selectKit=this.selectKit
          }}
        {{/each}}
      {{/if}}

      {{component
        this.selectKit.options.filterComponent
        selectKit=this.selectKit
        id=(concat this.selectKit.uniqueID "-filter")
        hidePlaceholderWithSelection=true
      }}
    </div>
  {{else}}
    <MultiSelect::FormatSelectedContent
      @content={{or this.selectedContent this.selectKit.noneItem}}
      @selectKit={{this.selectKit}}
    />

    {{d-icon this.caretIcon class="caret-icon"}}
  {{/if}}
</div>