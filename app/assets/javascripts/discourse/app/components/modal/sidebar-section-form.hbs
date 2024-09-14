<DModal
  @closeModal={{@closeModal}}
  @flash={{this.flash}}
  @flashType={{this.flashType}}
  @title={{i18n this.header}}
  class="sidebar-section-form-modal"
>
  <:body>
    <form class="form-horizontal sidebar-section-form">
      {{#unless this.transformedModel.hideTitleInput}}
        <div class="sidebar-section-form__input-wrapper">
          <label for="section-name">
            {{i18n "sidebar.sections.custom.title.label"}}
          </label>

          <Input
            name="section-name"
            @type="text"
            @value={{this.transformedModel.title}}
            class={{this.transformedModel.titleCssClass}}
            id="section-name"
            {{on
              "input"
              (with-event-value (fn (mut this.transformedModel.title)))
            }}
          />

          {{#if this.transformedModel.invalidTitleMessage}}
            <div class="title warning">
              {{this.transformedModel.invalidTitleMessage}}
            </div>
          {{/if}}
        </div>
      {{/unless}}
      <div
        role="table"
        aria-rowcount={{this.activeLinks.length}}
        class="sidebar-section-form__links-wrapper"
      >

        <div class="row-wrapper header" role="row">
          <div
            class="input-group link-icon"
            role="columnheader"
            aria-sort="none"
          >
            <label>{{i18n "sidebar.sections.custom.links.icon.label"}}</label>
          </div>

          <div
            class="input-group link-name"
            role="columnheader"
            aria-sort="none"
          >
            <label>{{i18n "sidebar.sections.custom.links.name.label"}}</label>
          </div>

          <div
            class="input-group link-url"
            role="columnheader"
            aria-sort="none"
          >
            <label>{{i18n "sidebar.sections.custom.links.value.label"}}</label>
          </div>
        </div>

        {{#each this.activeLinks as |link|}}
          <Sidebar::SectionFormLink
            @link={{link}}
            @deleteLink={{this.deleteLink}}
            @reorderCallback={{this.reorder}}
            @setDraggedLinkCallback={{this.setDraggedLink}}
          />
        {{/each}}

      </div>
      <DButton
        @action={{this.addLink}}
        @title="sidebar.sections.custom.links.add"
        @icon="plus"
        @label="sidebar.sections.custom.links.add"
        @ariaLabel="sidebar.sections.custom.links.add"
        class="btn-flat btn-text add-link"
      />

      {{#if this.transformedModel.sectionType}}
        <hr />
        <h3>{{i18n "sidebar.sections.custom.more_menu"}}</h3>
        {{#each this.activeSecondaryLinks as |link|}}
          <Sidebar::SectionFormLink
            @link={{link}}
            @deleteLink={{this.deleteLink}}
            @reorderCallback={{this.reorder}}
            @setDraggedLinkCallback={{this.setDraggedLink}}
          />
        {{/each}}
        <DButton
          @action={{this.addSecondaryLink}}
          @title="sidebar.sections.custom.links.add"
          @icon="plus"
          @label="sidebar.sections.custom.links.add"
          @ariaLabel="sidebar.sections.custom.links.add"
          class="btn-flat btn-text add-link"
        />
      {{/if}}
    </form>
  </:body>
  <:footer>
    <DButton
      @action={{this.save}}
      @label="sidebar.sections.custom.save"
      @ariaLabel="sidebar.sections.custom.save"
      @disabled={{not this.transformedModel.valid}}
      id="save-section"
      class="btn-primary"
    />
    {{#if (and this.currentUser.admin)}}
      <div
        class="mark-public-wrapper
          {{if this.transformedModel.sectionType '-disabled'}}"
      >
        <label class="checkbox-label">
          {{#if this.transformedModel.sectionType}}
            <DTooltip
              @content={{i18n "sidebar.sections.custom.always_public"}}
              class="always-public-tooltip"
            >
              <:trigger>
                {{d-icon "square-check"}}
                <span>{{i18n "sidebar.sections.custom.public"}}</span>
              </:trigger>
            </DTooltip>
          {{else}}
            <Input
              @type="checkbox"
              @checked={{this.transformedModel.public}}
              class="mark-public"
              disabled={{this.transformedModel.sectionType}}
            />
            <span>{{i18n "sidebar.sections.custom.public"}}</span>
          {{/if}}
        </label>
      </div>
    {{/if}}
    {{#if this.canDelete}}
      <DButton
        @icon="trash-can"
        @action={{this.delete}}
        @label="sidebar.sections.custom.delete"
        @ariaLabel="sidebar.sections.custom.delete"
        id="delete-section"
        class="btn-danger delete"
      />
    {{/if}}
    {{#if this.transformedModel.sectionType}}
      <DButton
        @action={{this.resetToDefault}}
        @icon="arrow-rotate-left"
        @title="sidebar.sections.custom.links.reset"
        @label="sidebar.sections.custom.links.reset"
        @ariaLabel="sidebar.sections.custom.links.reset"
        class="btn-flat btn-text reset-link"
      />
    {{/if}}
  </:footer>
</DModal>