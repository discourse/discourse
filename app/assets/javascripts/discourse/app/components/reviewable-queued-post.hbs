<ReviewableTopicLink @reviewable={{@reviewable}} @tagName="">
  <div class="title-text">
    {{d-icon "square-plus" title="review.new_topic"}}
    {{@reviewable.payload.title}}
  </div>
  {{category-badge @reviewable.category}}
  <ReviewableTags @tags={{@reviewable.payload.tags}} @tagName="" />
  {{#if @reviewable.payload.via_email}}
    <a href {{on "click" this.showRawEmail}} class="show-raw-email">
      {{d-icon "envelope" title="post.via_email"}}
    </a>
  {{/if}}
</ReviewableTopicLink>

<div class="post-contents-wrapper">
  <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />

  <div class="post-contents">
    <ReviewablePostHeader
      @reviewable={{@reviewable}}
      @createdBy={{@reviewable.target_created_by}}
      @tagName=""
    />

    <CookText
      class="post-body {{if this.isCollapsed 'is-collapsed'}}"
      @rawText={{@reviewable.payload.raw}}
      @categoryId={{@reviewable.category_id}}
      @topicId={{@reviewable.topic_id}}
      @paintOneboxes={{true}}
      @opts={{hash removeMissing=true}}
      @onOffsetHeightCalculated={{this.setPostBodyHeight}}
    />

    {{#if this.isLongPost}}
      <DButton
        @action={{this.toggleContent}}
        @label={{this.collapseButtonProps.label}}
        @icon={{this.collapseButtonProps.icon}}
        class="btn-default btn-icon post-body__toggle-btn"
      />
    {{/if}}

    {{yield}}
  </div>
</div>