<DModal
  @title={{if
    this.post
    (i18n "post.share.title" post_number=this.post.post_number)
    (i18n "topic.share.title")
  }}
  @subtitle={{if this.post this.displayDate}}
  @closeModal={{@closeModal}}
  @flash={{this.flash}}
  @flashType={{this.flashType}}
  class="share-topic-modal"
>
  <form>
    <div class="input-group invite-link">
      <label for="invite-link">
        {{if
          this.post
          (i18n "post.share.instructions" post_number=this.post.post_number)
          (i18n "topic.share.instructions")
        }}
      </label>
      <div class="link-share-container">
        <Input
          id="invite-link"
          name="invite-link"
          class="invite-link"
          @value={{this.url}}
          readonly={{true}}
          size="200"
        />
        <CopyButton @selector="input.invite-link" @ariaLabel="share.url" />
      </div>
    </div>

    <div class="link-share-actions">
      <div class="sources">
        {{#each this.sources as |source|}}
          <ShareSource @source={{source}} @action={{this.share}} />
        {{/each}}

        {{#if this.allowInvites}}
          <DButton
            @label="topic.share.invite_users"
            @icon="user-plus"
            @action={{this.inviteUsers}}
            class="btn-default invite"
          />
        {{/if}}

        {{#if this.topic.details.can_reply_as_new_topic}}
          {{#if this.topic.isPrivateMessage}}
            <DButton
              @action={{this.replyAsNewTopic}}
              @icon="plus"
              @ariaLabel="post.reply_as_new_private_message"
              @title="post.reply_as_new_private_message"
              @label="user.new_private_message"
              class="btn-default new-topic"
            />
          {{else}}
            <DButton
              @action={{this.replyAsNewTopic}}
              @icon="plus"
              @ariaLabel="post.reply_as_new_topic"
              @title="post.reply_as_new_topic"
              @label="topic.create"
              class="btn-default new-topic"
            />
          {{/if}}
        {{/if}}
        <PluginOutlet
          @name="share-topic-sources"
          @outletArgs={{hash topic=this.topic post=this.post}}
        />
      </div>
    </div>
  </form>
</DModal>