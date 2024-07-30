{{#each this.filteredResultTypes as |resultType|}}
  <div class={{resultType.componentName}}>
    <PluginOutlet
      @name="search-menu-results-type-top"
      @outletArgs={{hash resultType=resultType}}
    />
    <ul
      class="list"
      aria-label={{concat (i18n "search.results") " " resultType.type}}
    >
      {{#each resultType.results as |result|}}
        {{! template-lint-disable no-pointer-down-event-binding }}
        {{! template-lint-disable no-invalid-interactive }}
        <li
          class="item"
          {{on
            "keydown"
            (fn this.onKeydown (hash resultType=resultType result=result))
          }}
        >
          <a
            href={{or result.url result.path}}
            {{on
              "click"
              (fn this.onClick (hash resultType=resultType result=result))
            }}
            class="search-link"
          >
            <resultType.component
              @result={{result}}
              @displayNameWithUser={{@displayNameWithUser}}
            />
          </a>
        </li>
      {{/each}}
    </ul>
  </div>
{{/each}}