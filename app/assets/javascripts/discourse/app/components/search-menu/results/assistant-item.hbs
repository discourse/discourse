{{! template-lint-disable no-pointer-down-event-binding }}
{{! template-lint-disable no-invalid-interactive }}
<li
  class={{concat-class @typeClass "search-menu-assistant-item"}}
  {{on "keydown" this.onKeydown}}
  {{on "click" this.onClick}}
  data-usage={{@usage}}
>
  <a class="search-link" href={{this.href}}>
    <span aria-label={{i18n "search.title"}}>
      {{d-icon (or @icon "magnifying-glass")}}
    </span>

    {{#if this.prefix}}
      <span class="search-item-prefix">
        {{this.prefix}}
      </span>
    {{/if}}

    {{#if @withInLabel}}
      <span class="label-suffix">{{i18n "search.in"}}</span>
    {{/if}}

    {{#if @category}}
      <SearchMenu::Results::Type::Category @result={{@category}} />
      {{#if (and @tag @isIntersection)}}
        <span class="search-item-tag">
          {{d-icon "tag"}}{{@tag}}
        </span>
      {{/if}}
    {{else if @tag}}
      {{#if (and @isIntersection @additionalTags.length)}}
        <span class="search-item-tag">{{this.tagsSlug}}</span>
      {{else}}
        <span class="search-item-tag">
          <SearchMenu::Results::Type::Tag @result={{@tag}} />
        </span>
      {{/if}}
    {{else if @user}}
      <span class="search-item-user">
        <SearchMenu::Results::Type::User @result={{@user}} />
      </span>
    {{/if}}

    <span class="search-item-slug">
      {{#if @suffix}}
        <span class="label-suffix">{{@suffix}}</span>
      {{/if}}
      {{@label}}
    </span>
    {{#if @extraHint}}
      <span class="extra-hint">
        {{i18n "search.enter_hint"}}
      </span>
    {{/if}}
  </a>
</li>