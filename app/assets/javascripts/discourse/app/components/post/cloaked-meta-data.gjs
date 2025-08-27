/**
 * @component PostCloakedMetaData
 *
 * Provides a minimal metadata display for cloaked posts to maintain
 * accessibility while posts are virtualized/cloaked in the post stream.
 * This ensures screen readers can still navigate between posts even when
 * the full post content is not rendered.
 */
<template>
  <div class="topic-meta-data topic-meta-data--cloaked">
    <span class="post-meta-username">{{@post.username}}</span>
    <span class="post-meta-date">{{@post.created_at}}</span>
  </div>
</template>
