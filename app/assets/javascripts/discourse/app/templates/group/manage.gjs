<section class="user-secondary-navigation">
  <HorizontalOverflowNav class="activity-nav">
    {{#each this.tabs as |tab|}}
      <li>
        <LinkTo @route={{tab.route}} @model={{this.model.name}}>
          {{i18n tab.title}}
        </LinkTo>
      </li>
    {{/each}}
  </HorizontalOverflowNav>
</section>
<section class="user-content" id="user-content">
  {{outlet}}
</section>