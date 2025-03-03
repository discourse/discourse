{{#if (gt this.visibleTargets.length 1)}}
  <div class="edit-main-nav admin-controls">
    <nav>
      <ul class="nav nav-pills target">
        {{#each this.visibleTargets as |target|}}
          <li>
            <LinkTo
              @route={{this.editRouteName}}
              @models={{array this.theme.id target.name this.fieldName}}
              @replace={{true}}
              title={{this.field.title}}
              class={{if target.edited "edited" "blank"}}
            >
              {{#if target.error}}{{d-icon "triangle-exclamation"}}{{/if}}
              {{#if target.icon}}{{d-icon target.icon}}{{/if}}
              {{i18n (concat "admin.customize.theme." target.name)}}
            </LinkTo>
          </li>
        {{/each}}
        <li class="spacer"></li>
        <li>
          <label>
            <Input
              @type="checkbox"
              @checked={{this.showAdvanced}}
              {{on "click" this.toggleShowAdvanced}}
            />
            {{i18n "admin.customize.theme.show_advanced"}}
          </label>
        </li>
      </ul>
    </nav>
  </div>
{{/if}}

<div class="admin-controls">
  <nav>
    <ul class="nav nav-pills fields">
      {{#each this.visibleFields as |field|}}
        <li>
          <LinkTo
            @route={{this.editRouteName}}
            @models={{array this.theme.id this.currentTargetName field.name}}
            @replace={{true}}
            title={{field.title}}
            class={{if field.edited "edited" "blank"}}
          >
            {{#if field.error}}{{d-icon "triangle-exclamation"}}{{/if}}
            {{#if field.icon}}{{d-icon field.icon}}{{/if}}
            {{field.translatedName}}
          </LinkTo>
        </li>
      {{/each}}

      <li class="spacer"></li>
      <li>
        {{#if (lte this.visibleTargets.length 1)}}
          <label>
            <Input
              @type="checkbox"
              @checked={{this.showAdvanced}}
              {{on "click" this.toggleShowAdvanced}}
            />
            {{i18n "admin.customize.theme.show_advanced"}}
          </label>
        {{/if}}
        <a href {{on "click" this.toggleMaximize}} class="no-text">
          {{d-icon this.maximizeIcon}}
        </a>
      </li>
    </ul>
  </nav>
</div>

{{#if this.error}}
  <pre class="field-error">{{this.error}}</pre>
{{/if}}

{{#if this.warning}}
  <pre class="field-warning">{{html-safe this.warning}}</pre>
{{/if}}

<div class="field-info">
  {{this.currentField.title}}
</div>

<AceEditor
  @content={{this.activeSection}}
  @onChange={{fn (mut this.activeSection)}}
  @editorId={{this.editorId}}
  @mode={{this.activeSectionMode}}
  @autofocus="true"
  @placeholder={{this.placeholder}}
  @htmlPlaceholder={{true}}
  @save={{this.save}}
  @setWarning={{this.setWarning}}
/>