{{#each this.categories as |c|}}
  <div
    data-notification-level={{c.notificationLevelString}}
    style={{category-color-variable c.color}}
    class="category category-box category-box-{{c.slug}}
      {{if c.isMuted 'muted'}}"
  >
    <div class="category-box-inner">
      <div class="category-box-heading">
        <a class="parent-box-link" href={{c.url}}>
          {{#unless c.isMuted}}
            {{#if c.uploaded_logo.url}}
              <CategoryLogo @category={{c}} />
            {{/if}}
          {{/unless}}

          <h3>
            <CategoryTitleBefore @category={{c}} />
            {{#if c.read_restricted}}
              {{d-icon this.lockIcon}}
            {{/if}}
            {{c.displayName}}
          </h3>
        </a>
      </div>

      {{#unless c.isMuted}}
        <div class="featured-topics">
          {{#if c.topics}}
            <ul>
              {{#each c.topics as |topic|}}
                <CategoriesBoxesTopic @topic={{topic}} />
              {{/each}}
            </ul>
          {{/if}}
        </div>
      {{/unless}}

      <PluginOutlet
        @name="category-box-below-each-category"
        @outletArgs={{hash category=c}}
      />
    </div>
  </div>
{{/each}}