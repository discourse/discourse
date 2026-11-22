# frozen_string_literal: true

# Every site has a default blog. Syncing on every deploy also picks up settings
# overridden in the environment, which change without a setting change event.
Blog::DefaultBlogMirror.sync!
