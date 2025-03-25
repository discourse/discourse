<DModal
  @title={{i18n "admin.user.delete_posts.progress.title"}}
  @closeModal={{@closeModal}}
  class="admin-delete-user-posts-progress-modal"
  @flash={{this.flash}}
  @dismissable={{false}}
>
  <:body>
    <p>{{i18n "admin.user.delete_posts.progress.description"}}</p>
    <div class="progress-bar">
      <span style={{html-safe (concat "width: " this.deletedPercentage "%")}} />
    </div>
  </:body>
</DModal>