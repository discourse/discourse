# Comment System Enhancements

This document outlines the work needed to make the post-voting comment system more "full-featured" - closer to mini-posts than lightweight comments.

## Current State

- Comments are stored in `post_voting_comments` table (separate from Posts)
- Flat structure (no nesting, no reply-to)
- **Full markdown support** via DEditor with filtered toolbar (bold, italic, link, code, lists, blockquote)
- **Upload support** via UppyUpload (toolbar button + drag and drop)
- Max 10 comments per post, max 2000 characters
- First 5 comments preloaded, "load more" fetches rest
- No mentions, no deep linking, no search integration

---

## Completed Features

### 1. Full Markdown Support ✅ DONE

**Goal**: Enable full markdown rendering for comments (mini-posts).

**Status**: Complete

**Changes completed**:
- [x] Switched to full `PrettyText.cook()` pipeline (removed limited feature set)
- [x] Bumped `COOKED_VERSION` to 2 to trigger re-cook of existing comments
- [x] Increased `post_voting_comment_max_raw_length` from 600 to 2000 chars
- [x] Made the setting visible (removed `hidden: true`)
- [x] Replaced textarea with DEditor component for rich text editing
- [x] Filtered toolbar to basic formatting: bold, italic, link, blockquote, code, bullet, list
- [x] Hidden preview panel (comments don't need side-by-side preview)
- [x] Updated CSS to support full markdown content display (code blocks, lists, blockquotes)
- [x] Updated tests to reflect new behavior

**Files modified**:
- `app/models/post_voting_comment.rb` - now uses full `PrettyText.cook()`
- `config/settings.yml` - increased max length to 2000, unhidden the setting
- `assets/javascripts/discourse/components/post-voting-comment-composer.gjs` - uses DEditor
- `assets/stylesheets/common/post-voting.scss` - styles for editor and markdown content
- `spec/models/post_voting_comment_spec.rb` - updated tests for new behavior

---

### 2. Upload Support ✅ DONE

**Goal**: Allow image/file uploads in comments.

**Status**: Complete

**Changes completed**:
- [x] Integrated `UppyUpload` for file uploads
- [x] Added upload button to toolbar (when `allow_uploads` site setting is enabled)
- [x] Implemented drag and drop support onto the comment editor
- [x] Captures `textManipulation` from DEditor via `@onSetup` callback
- [x] Inserts appropriate markdown for different file types:
  - Images: `![filename|WxH](upload://...)`
  - Videos: `![filename|video](upload://...)`
  - Audio: `![filename|audio](upload://...)`
  - Other files: `[filename|attachment](upload://...)`
- [x] Respects site upload settings (allowed extensions, size limits, S3 support)

**Implementation details**:
- Uses `UppyUpload` (simpler than `UppyComposerUpload`)
- Drop target configured via `uploadDropTargetOptions` pointing to composer element
- File input manually bound for toolbar button clicks
- Hidden file input element with `multiple` support

**Files modified**:
- `assets/javascripts/discourse/components/post-voting-comment-composer.gjs` - UppyUpload integration
- `assets/stylesheets/common/post-voting.scss` - hidden file input styles

---

## Remaining Features

### 3. Mentions (`@username`)

**Goal**: Support @mentions in comments with notifications.

**Changes needed**:
- [ ] Enable mentions in PrettyText features (may already work with full cook)
- [ ] Extract mentioned users after cooking (like `Post.extract_mentioned_users`)
- [ ] Create notifications for mentioned users
- [ ] Register notification type if needed (`post_voting_comment_mention`)
- [ ] Handle notification click → navigate to comment (depends on deep linking)
- [ ] Consider group mentions (`@moderators`)

**Implementation approach**:
```ruby
# In PostVotingComment model or CommentCreator service
def extract_and_notify_mentions
  mentions = PrettyText.extract_mentions(cooked)
  mentions.each do |username|
    user = User.find_by_username(username)
    next unless user
    # Create notification
  end
end
```

**Questions to resolve**:
- Reuse existing `Notification.types[:mentioned]` or create new type?
- How to link notification to comment (needs deep linking first)?
- Rate limiting on mentions to prevent spam?

**Files**:
- `app/models/post_voting_comment.rb`
- `lib/post_voting/comment_creator.rb`
- Possibly `config/locales/` for notification text

---

### 4. Deep Linking to Comments

**Goal**: URL scheme to link directly to a specific comment.

**Proposed URL format**:
```
/t/topic-slug/123/4?comment=456
# or
/t/topic-slug/123/4#pv-comment-456
```

**Changes needed**:
- [ ] Add unique anchor IDs to comment elements (`id="pv-comment-{id}"`)
- [ ] Parse URL on topic load for comment parameter
- [ ] Ensure target comment's parent post is loaded/visible
- [ ] Ensure target comment is loaded (handle pagination)
- [ ] Scroll to and highlight the comment
- [ ] Add "copy link" action to comment action menu

**Implementation approach**:
1. Fragment-based (`#pv-comment-456`): Simpler, browser handles scroll, but won't work if comment not in DOM
2. Query param (`?comment=456`): More control, can ensure comment is loaded first

**Recommendation**: Use query param for robustness, redirect to fragment after load.

**Questions to resolve**:
- What if comment is on a post that's not in the current post stream?
- How to handle deleted comments in deep links?
- Should we support linking from notifications, emails, search results?

**Files**:
- `assets/javascripts/discourse/components/post-voting-comment.gjs` - add anchor ID
- `assets/javascripts/discourse/components/post-voting-comments.gjs` - handle deep link
- `assets/javascripts/discourse/components/post-voting-comment-actions.gjs` - add copy link
- May need route modification or initializer for URL parsing

---

### 5. Comment Pagination

**Goal**: Support more than 10 comments per post with proper pagination.

**Current state**:
- `post_voting_comment_limit_per_post` defaults to 10
- Validation in model prevents more than limit
- Preloads first 5, "load more" fetches rest (all at once)

**Changes needed**:
- [ ] Remove or significantly raise the comment limit
- [ ] Implement cursor-based pagination in `CommentsController#load_more_comments`
- [ ] Add `limit` parameter to load_more endpoint
- [ ] Update frontend to request pages of comments
- [ ] Consider sort order: by votes, by date, or configurable?
- [ ] Handle "load more" state properly (show count remaining)

**API change**:
```
GET /post_voting/comments?post_id=123&last_comment_id=456&limit=20
Response: { comments: [...], has_more: true }
```

**Questions to resolve**:
- What should the default page size be?
- Sort by votes (Reddit-style) or chronological?
- How does pagination interact with deep linking?
- Performance with hundreds of comments?

**Files**:
- `app/controllers/post_voting/comments_controller.rb`
- `app/models/post_voting_comment.rb` - remove/adjust limit validation
- `config/settings.yml` - adjust or remove limit setting
- `assets/javascripts/discourse/components/post-voting-comments.gjs`
- `assets/javascripts/discourse/components/post-voting-comments-menu.gjs`

---

### 6. Email Notifications

**Goal**: Include comment activity in email notifications.

**Changes needed**:
- [ ] Verify comment notifications trigger emails (check notification type config)
- [ ] Include mention notifications in email
- [ ] Add comments to email digest if applicable
- [ ] Email templates for comment notifications

**Questions to resolve**:
- Should comment replies appear in digest emails?
- Separate email preferences for comment notifications?

**Files**:
- Check `Notification.types` registration
- Email templates in `config/locales/`
- Possibly `app/mailers/` if custom mailer needed

---

### 7. Search Integration

**Goal**: Make comment content searchable.

**Changes needed**:
- [ ] Index `PostVotingComment` content in search
- [ ] Return comment results with context (parent post, topic)
- [ ] Link search results to comment (needs deep linking)
- [ ] Handle comment updates/deletes in search index

**Complexity**: High - requires integration with Discourse search infrastructure.

**Questions to resolve**:
- Use existing search infrastructure or separate index?
- How to display comment search results in UI?
- Performance impact of indexing comments?

**Files**:
- May need new search data source
- `lib/search.rb` modifications or extensions

---

### 8. Editing Improvements

**Goal**: Better editing experience for comments.

**Changes needed**:
- [ ] Show "edited" indicator with timestamp
- [ ] Edit history/revisions (like posts have)
- [ ] Track `last_editor_id` (already in schema)
- [ ] Show edit reason (optional)

**Current state**: `last_editor_id` exists but unclear if surfaced in UI.

**Files**:
- `app/serializers/post_voting_comment_serializer.rb` - add edited fields
- `assets/javascripts/discourse/components/post-voting-comment.gjs` - show edited indicator

---

### 9. Emoji Picker Integration

**Goal**: Add emoji picker button to comment toolbar.

**Changes needed**:
- [ ] Add emoji button to toolbar in `configureToolbar`
- [ ] Wire up emoji picker modal/popover
- [ ] Insert selected emoji at cursor position

**Complexity**: Low - DEditor already has emoji support, just need to enable the button.

---

### 10. Real-time Presence

**Goal**: Show who is viewing/typing in comments.

**Changes needed**:
- [ ] Typing indicators when composing comment
- [ ] "X users viewing this post" indicator
- [ ] Use Discourse presence system

**Complexity**: Medium - leverage existing presence infrastructure.

---

## Technical Debt / Improvements

### Performance

- [ ] `Topic.post_voting_votes` is marked "very inefficient" - refactor
- [ ] Consider caching strategies for high-traffic topics
- [ ] Review N+1 queries in comment loading

### Testing

- [ ] Add system specs for new features
- [ ] Add unit tests for mention extraction
- [ ] Add API tests for pagination
- [ ] Add tests for upload functionality

### Accessibility

- [ ] Ensure keyboard navigation works for comments
- [ ] Screen reader support for vote counts, comment actions
- [ ] ARIA labels on interactive elements

---

## Implementation Order (Suggested)

1. ~~**Full Markdown**~~ ✅ Done
2. ~~**Uploads**~~ ✅ Done
3. **Deep Linking** - Foundation for notifications and search results
4. **Mentions** - High-value feature, depends on deep linking for notifications
5. **Pagination** - Unlocks unlimited comments
6. **Emoji Picker** - Quick win, improves UX
7. **Editing Improvements** - Polish
8. **Email Notifications** - Depends on notification types being solid
9. **Search Integration** - Larger effort, do last
10. **Real-time Presence** - Nice to have

---

## Open Questions

1. ~~**Character limit**: Is 600 chars enough for mini-posts?~~ → Increased to 2000
2. ~~**Uploads**: Do we want image uploads in comments?~~ → Yes, implemented
3. **Reactions**: Beyond upvotes, do we want emoji reactions on comments?
4. **Moderation**: Are current flagging/review tools sufficient?
5. **API stability**: Are we okay changing the comments API for pagination?
