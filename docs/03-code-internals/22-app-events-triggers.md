---
title: AppEvents Triggers Reference
short_title: AppEvents Triggers
id: app-events-triggers
---

<div data-theme-toc="true"> </div>

## AppEvents
The AppEvent system in Discourse provides a pub/sub mechanism for handling UI updates and component interactions - and these events are triggered via calls of `AppEvent.trigger`.

This topic consolidates a list of all such event triggers and their arguments, along with line-of-code references to the Discourse source code.


### ace
#### ace:resize [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/admin/addon/components/admin-theme-editor.js#L109)

No arguments passed to this event.


### bookmarks
#### bookmarks:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/bookmark-list.js#L40)

| Position | Argument                      | Type            | Always Present | Description |
| -------- | ----------------------------- | --------------- | -------------- | ----------- |
| 1        | bookmarkFormData.saveData     | property        | True           | -           |
| 2        | this.bookmarkModel.attachedTo | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/bookmark-list.js#40 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/bookmark-list.js#L40)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | null                | null            | -           |
| 2        | bookmark.attachedTo | called_function | -           |

##### /app/assets/javascripts/discourse/app/components/bookmark-list.js#78 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/bookmark-list.js#L78)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | savedData           | variable        | -           |
| 2        | bookmark.attachedTo | called_function | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1376 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1376)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

##### /app/assets/javascripts/discourse/app/lib/topic-bookmark-manager.js#57 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/topic-bookmark-manager.js#L57)

| Position | Argument                      | Type            | Description |
| -------- | ----------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData     | property        | -           |
| 2        | this.bookmarkModel.attachedTo | called_function | -           |

##### /app/assets/javascripts/discourse/app/models/post.js#526 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post.js#L526)

| Position | Argument            | Type     | Description |
| -------- | ------------------- | -------- | ----------- |
| 1        | data                | variable | -           |
| 2        | objectArg2          | object   | -           |
| -        | objectArg2.target   | string   | -           |
| -        | objectArg2.targetId | property | -           |

##### /app/assets/javascripts/discourse/app/models/post.js#547 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post.js#L547)

| Position | Argument            | Type     | Description |
| -------- | ------------------- | -------- | ----------- |
| 1        | null                | null     | -           |
| 2        | objectArg2          | object   | -           |
| -        | objectArg2.target   | string   | -           |
| -        | objectArg2.targetId | property | -           |

##### /app/assets/javascripts/discourse/app/models/topic.js#688 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/topic.js#L688)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | null                | null            | -           |
| 2        | bookmark.attachedTo | called_function | -           |

##### /plugins/chat/assets/javascripts/discourse/lib/chat-message-interactor.js#343 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/lib/chat-message-interactor.js#L343)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

</details>


### card
#### card:close [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat/direct-message-button.gjs#L32)

No arguments passed to this event.

#### card:hide [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/card-contents-base.js#L263)

No arguments passed to this event.

#### card:show [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/card-contents-base.js#L63)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | username | variable | True           | -           |
| 2        | target   | variable | True           | -           |
| 3        | event    | variable | True           | -           |


### chat
#### chat:message_interaction [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-message/blocks/index.gjs#L18)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | result1.interaction | property | True           | -           |

#### chat:modify-selection [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L72)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | event              | variable | True           | -           |
| 2        | objectArg2         | object   | True           | -           |
| -        | objectArg2.type    | variable | True           | -           |
| -        | objectArg2.context | property | True           | -           |

#### chat:open-insert-link-modal [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L84)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | event              | variable | True           | -           |
| 2        | objectArg2         | object   | True           | -           |
| -        | objectArg2.context | property | True           | -           |

#### chat:open-url [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/routes/chat.js#L48)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | url      | variable | True           | -           |

#### chat:refresh-channel-members [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat-subscriptions-manager.js#L469)

No arguments passed to this event.

#### chat:rerender-header [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-drawer.js#L91)

No arguments passed to this event.

#### chat:toggle-close [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L110)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | event    | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#110 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L110)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | event    | variable | -           |

##### /plugins/chat/assets/javascripts/discourse/routes/chat.js#53 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/routes/chat.js#L53)

No arguments passed to this event.

</details>

#### chat:toggle-expand [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-drawer.js#L208)

| Position | Argument                               | Type     | Always Present | Description |
| -------- | -------------------------------------- | -------- | -------------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/chat/assets/javascripts/discourse/components/chat-drawer.js#208 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-drawer.js#L208)

| Position | Argument                               | Type     | Description |
| -------- | -------------------------------------- | -------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | -           |

##### /plugins/chat/assets/javascripts/discourse/services/chat.js#455 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat.js#L455)

| Position | Argument                               | Type     | Description |
| -------- | -------------------------------------- | -------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | -           |

</details>


### composer
#### composer:cancel-upload [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L644)

No arguments passed to this event.

#### composer:cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1691)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/services/composer.js#1691 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1691)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/services/composer.js#1699 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1699)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/services/composer.js#1712 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1712)

No arguments passed to this event.

</details>

#### composer:created-post [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1212)

No arguments passed to this event.

#### composer:div-resizing [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L93)

No arguments passed to this event.

#### composer:edited-post [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1200)

No arguments passed to this event.

#### composer:find-similar [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L67)

No arguments passed to this event.

#### composer:insert-block [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L473)

| Position | Argument        | Type            | Always Present | Description |
| -------- | --------------- | --------------- | -------------- | ----------- |
| 1        | quotedText.trim | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/controllers/topic.js#473 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L473)

| Position | Argument   | Type     | Description |
| -------- | ---------- | -------- | ----------- |
| 1        | quotedText | variable | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#694 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L694)

| Position | Argument        | Type            | Description |
| -------- | --------------- | --------------- | ----------- |
| 1        | quotedText.trim | called_function | -           |

</details>

#### composer:insert-text [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/search.js#L42)

| Position | Argument                    | Type     | Always Present | Description |
| -------- | --------------------------- | -------- | -------------- | ----------- |
| 1        | document.activeElement.href | property | True           | -           |
| 2        | objectArg2                  | object   | True           | -           |
| -        | objectArg2.ensureSpace      | boolean  | True           | -           |

#### composer:open [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1443)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.model | property | True           | -           |

#### composer:opened [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L177)

No arguments passed to this event.

#### composer:reply-reloaded [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L944)

| Position | Argument | Type | Always Present | Description |
| -------- | -------- | ---- | -------------- | ----------- |
| 1        | this     | this | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/models/composer.js#944 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L944)

| Position | Argument | Type | Description |
| -------- | -------- | ---- | ----------- |
| 1        | this     | this | -           |

##### /app/assets/javascripts/discourse/app/models/composer.js#970 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L970)

| Position | Argument | Type | Description |
| -------- | -------- | ---- | ----------- |
| 1        | this     | this | -           |

</details>

#### composer:resize-ended [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L150)

No arguments passed to this event.

#### composer:resize-started [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L145)

No arguments passed to this event.

#### composer:resized [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L127)

No arguments passed to this event.

#### composer:saved [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1181)

No arguments passed to this event.

#### composer:toolbar-popup-menu-button-clicked [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L673)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | menuItem | variable | True           | -           |

#### composer:typed-reply [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1295)

No arguments passed to this event.

#### this.composerEventPrefix:all-uploads-complete [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L398)

No arguments passed to this event.

#### this.composerEventPrefix:apply-surround [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L759)

| Position | Argument                | Type    | Always Present | Description |
| -------- | ----------------------- | ------- | -------------- | ----------- |
| 1        | [grid]                  | string  | True           | -           |
| 2        | [/grid]                 | string  | True           | -           |
| 3        | grid_surround           | string  | True           | -           |
| 4        | objectArg4              | object  | True           | -           |
| -        | objectArg4.useBlockMode | boolean | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#759 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L759)

| Position | Argument                | Type    | Description |
| -------- | ----------------------- | ------- | ----------- |
| 1        | [grid]                  | string  | -           |
| 2        | [/grid]                 | string  | -           |
| 3        | grid_surround           | string  | -           |
| 4        | objectArg4              | object  | -           |
| -        | objectArg4.useBlockMode | boolean | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#794 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L794)

| Position | Argument                | Type    | Description |
| -------- | ----------------------- | ------- | ----------- |
| 1        | [grid]                  | string  | -           |
| 2        | [/grid]                 | string  | -           |
| 3        | grid_surround           | string  | -           |
| 4        | objectArg4              | object  | -           |
| -        | objectArg4.useBlockMode | boolean | -           |

</details>

#### this.composerEventPrefix:closed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L800)

No arguments passed to this event.

#### this.composerEventPrefix:insert-text [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L344)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | placeholder | variable | True           | -           |

#### this.composerEventPrefix:replace-text [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L600)

| Position | Argument                                  | Type            | Always Present | Description |
| -------- | ----------------------------------------- | --------------- | -------------- | ----------- |
| 1        | placeholderData.uploadPlaceholder.replace | called_function | True           | -           |
| 2        | placeholderData.processingPlaceholder     | property        | True           | -           |
| 3        | objectArg3                                | object          | False          | -           |
| -        | objectArg3.regex                          | variable        | False          | -           |
| -        | objectArg3.index                          | variable        | False          | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#600 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L600)

| Position | Argument                  | Type     | Description |
| -------- | ------------------------- | -------- | ----------- |
| 1        | matchingPlaceholder.index | property | -           |
| 2        | replacement               | variable | -           |
| 3        | objectArg3                | object   | -           |
| -        | objectArg3.regex          | variable | -           |
| -        | objectArg3.index          | variable | -           |

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#644 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L644)

| Position | Argument    | Type     | Description |
| -------- | ----------- | -------- | ----------- |
| 1        | match       | variable | -           |
| 2        | replacement | variable | -           |

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#731 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L731)

| Position | Argument                  | Type     | Description |
| -------- | ------------------------- | -------- | ----------- |
| 1        | matchingPlaceholder.index | property | -           |
| 2        | string                    | string   | -           |
| 3        | objectArg3                | object   | -           |
| -        | objectArg3.regex          | variable | -           |
| -        | objectArg3.index          | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#383 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L383)

| Position | Argument                      | Type            | Description |
| -------- | ----------------------------- | --------------- | ----------- |
| 1        | this...uploadPlaceholder.trim | called_function | -           |
| 2        | markdown                      | variable        | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#418 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L418)

| Position | Argument               | Type     | Description |
| -------- | ---------------------- | -------- | ----------- |
| 1        | data.uploadPlaceholder | property | -           |
| 2        | string                 | string   | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#516 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L516)

| Position | Argument                              | Type     | Description |
| -------- | ------------------------------------- | -------- | ----------- |
| 1        | placeholderData.uploadPlaceholder     | property | -           |
| 2        | placeholderData.processingPlaceholder | property | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#525 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L525)

| Position | Argument                                  | Type            | Description |
| -------- | ----------------------------------------- | --------------- | ----------- |
| 1        | placeholderData.uploadPlaceholder.replace | called_function | -           |
| 2        | placeholderData.processingPlaceholder     | property        | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#536 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L536)

| Position | Argument                              | Type     | Description |
| -------- | ------------------------------------- | -------- | ----------- |
| 1        | placeholderData.processingPlaceholder | property | -           |
| 2        | placeholderData.uploadPlaceholder     | property | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#625 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L625)

| Position | Argument                 | Type     | Description |
| -------- | ------------------------ | -------- | ----------- |
| 1        | this...uploadPlaceholder | property | -           |
| 2        | string                   | string   | -           |

</details>

#### this.composerEventPrefix:upload-cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L285)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file.id  | property | True           | -           |

#### this.composerEventPrefix:upload-error [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L451)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file     | variable | True           | -           |

#### this.composerEventPrefix:upload-started [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L350)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | file.name | property | True           | -           |

#### this.composerEventPrefix:upload-success [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L391)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | file.name | property | True           | -           |
| 2        | upload    | variable | True           | -           |

#### this.composerEventPrefix:uploads-aborted [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L131)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#131 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L131)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#178 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L178)

No arguments passed to this event.

</details>

#### this.composerEventPrefix:uploads-cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L430)

No arguments passed to this event.

#### this.composerEventPrefix:uploads-preprocessing-complete [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L549)

No arguments passed to this event.

#### this.composerEventPrefix:will-close [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L795)

No arguments passed to this event.

#### this.composerEventPrefix:will-open [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L210)

No arguments passed to this event.


### composer-messages
#### composer-messages:close [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L903)

No arguments passed to this event.

#### composer-messages:create [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L765)

| Position | Argument                | Type            | Always Present | Description |
| -------- | ----------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1              | object          | True           | -           |
| -        | objectArg1.extraClass   | string          | True           | -           |
| -        | objectArg1.templateName | string          | True           | -           |
| -        | objectArg1.body         | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/services/composer.js#765 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L765)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#775 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L775)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#954 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L954)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#978 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L978)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#987 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L987)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

</details>


### count-updated
#### count-updated:user.username_lower:key [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/user.js#L102)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | value    | variable | True           | -           |


### cta
#### cta:shown [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/signup-cta.js#L72)

No arguments passed to this event.


### d-editor
#### d-editor:preview-click-group-card [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-editor.js#L170)

| Position | Argument     | Type     | Always Present | Description |
| -------- | ------------ | -------- | -------------- | ----------- |
| 1        | event.target | property | True           | -           |
| 2        | event        | variable | True           | -           |

#### d-editor:preview-click-user-card [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-editor.js#L162)

| Position | Argument     | Type     | Always Present | Description |
| -------- | ------------ | -------- | -------------- | ----------- |
| 1        | event.target | property | True           | -           |
| 2        | event        | variable | True           | -           |

#### d-editor:toolbar-button-clicked [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/composer/toolbar.js#L140)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | button   | variable | True           | -           |


### destroyed-custom-html
#### destroyed-custom-html:this.name [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/custom-html.js#L40)

No arguments passed to this event.


### discourse
#### discourse:focus-changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/document-title.js#L40)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | session.hasFocus | property | True           | -           |


### discourse-reactions
#### discourse-reactions:reaction-toggled [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-reactions/assets/javascripts/discourse/models/discourse-reactions-custom-reaction.js#L23)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1          | object   | True           | -           |
| -        | objectArg1.post     | variable | True           | -           |
| -        | objectArg1.reaction | property | True           | -           |


### do-not-disturb
#### do-not-disturb:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/user.js#L1227)

| Position | Argument                  | Type     | Always Present | Description |
| -------- | ------------------------- | -------- | -------------- | ----------- |
| 1        | this.do_not_disturb_until | property | True           | -           |


### dom
#### dom:clean [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/clean-dom-on-route-change.js#L32)

No arguments passed to this event.


### draft
#### draft:destroyed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1622)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | key      | variable | True           | -           |


### emoji-picker
#### emoji-picker:close [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L898)

No arguments passed to this event.


### full-page-search
#### full-page-search:trigger-search [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/full-page-search.js#L563)

No arguments passed to this event.


### group
#### group:join [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/group-membership-button.js#L65)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | group    | variable | True           | -           |

#### group:leave [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/group-membership-button.js#L49)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | model    | variable | True           | -           |


### header
#### header:hide-topic [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic.js#L393)

No arguments passed to this event.

#### header:keyboard-trigger [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L451)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.type  | string   | True           | -           |
| -        | objectArg1.event | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#451 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L451)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#522 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L522)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#531 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L531)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#538 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L538)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/services/search.js#49 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/search.js#L49)

| Position | Argument        | Type   | Description |
| -------- | --------------- | ------ | ----------- |
| 1        | objectArg1      | object | -           |
| -        | objectArg1.type | string | -           |

</details>

#### header:show-topic [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/modal/convert-to-public-topic.js#L23)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic    | variable | True           | -           |

#### header:update-topic [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1750)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | composer.topic | property | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1750 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1750)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | topic    | variable | -           |

##### /app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#163 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#L163)

| Position | Argument | Type    | Description |
| -------- | -------- | ------- | ----------- |
| 1        | null     | null    | -           |
| 2        | 5000     | integer | -           |

##### /app/assets/javascripts/discourse/app/routes/topic.js#418 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic.js#L418)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | model    | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1205 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1205)

| Position | Argument       | Type     | Description |
| -------- | -------------- | -------- | ----------- |
| 1        | composer.topic | property | -           |

</details>


### inserted-custom-html
#### inserted-custom-html:this.name [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/custom-html.js#L33)

No arguments passed to this event.


### keyboard
#### keyboard:move-selection [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L790)

| Position | Argument                   | Type     | Always Present | Description |
| -------- | -------------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1                 | object   | True           | -           |
| -        | objectArg1.articles        | variable | True           | -           |
| -        | objectArg1.selectedArticle | variable | True           | -           |


### lightbox
#### LIGHTBOX_APP_EVENT_NAMES.CLOSE [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/lightbox.js#L142)

No arguments passed to this event.

#### LIGHTBOX_APP_EVENT_NAMES.CLOSED [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/lightbox.js#L109)

No arguments passed to this event.

#### LIGHTBOX_APP_EVENT_NAMES.ITEM_DID_CHANGE [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/lightbox.js#L92)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1             | object   | True           | -           |
| -        | objectArg1.currentItem | variable | True           | -           |

#### LIGHTBOX_APP_EVENT_NAMES.ITEM_WILL_CHANGE [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/lightbox.js#L85)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1             | object   | True           | -           |
| -        | objectArg1.currentItem | variable | True           | -           |

#### LIGHTBOX_APP_EVENT_NAMES.OPEN [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/lightbox.js#L129)

| Position | Argument                 | Type     | Always Present | Description |
| -------- | ------------------------ | -------- | -------------- | ----------- |
| 1        | objectArg1               | object   | True           | -           |
| -        | objectArg1.items         | variable | True           | -           |
| -        | objectArg1.startingIndex | variable | True           | -           |
| -        | objectArg1.callbacks     | object   | True           | -           |
| -        | objectArg1.options       | object   | True           | -           |

#### LIGHTBOX_APP_EVENT_NAMES.OPENED [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/lightbox.js#L77)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1             | object   | True           | -           |
| -        | objectArg1.items       | variable | True           | -           |
| -        | objectArg1.currentItem | variable | True           | -           |


### notifications
#### notifications:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#L155)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#155 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#L155)

No arguments passed to this event.

##### /plugins/chat/assets/javascripts/discourse/services/chat-tracking-state-manager.js#110 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat-tracking-state-manager.js#L110)

No arguments passed to this event.

</details>


### page
#### page:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/page-tracker.js#L41)

| Position | Argument                           | Type            | Always Present | Description |
| -------- | ---------------------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1                         | object          | True           | -           |
| -        | objectArg1.url                     | variable        | True           | -           |
| -        | objectArg1.title                   | called_function | True           | -           |
| -        | objectArg1.currentRouteName        | property        | True           | -           |
| -        | objectArg1.replacedOnlyQueryParams | variable        | True           | -           |

#### page:compose-reply [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L672)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic    | variable | True           | -           |

#### page:like-toggled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/widgets/post.js#L1138)

| Position | Argument   | Type     | Always Present | Description |
| -------- | ---------- | -------- | -------------- | ----------- |
| 1        | post       | variable | True           | -           |
| 2        | likeAction | variable | True           | -           |

#### page:topic-loaded [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic-from-params.js#L93)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic    | variable | True           | -           |


### poll
#### poll:voted [:link:](https://github.com/discourse/discourse/blob/main/plugins/poll/assets/javascripts/discourse/components/poll.gjs#L188)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | poll1     | variable | True           | -           |
| 2        | this.post | property | True           | -           |
| 3        | this.vote | property | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/poll/assets/javascripts/discourse/components/poll.gjs#188 [:link:](https://github.com/discourse/discourse/blob/main/plugins/poll/assets/javascripts/discourse/components/poll.gjs#L188)

| Position | Argument  | Type     | Description |
| -------- | --------- | -------- | ----------- |
| 1        | poll1     | variable | -           |
| 2        | this.post | property | -           |
| 3        | this.vote | property | -           |

##### /plugins/poll/assets/javascripts/discourse/components/poll.gjs#442 [:link:](https://github.com/discourse/discourse/blob/main/plugins/poll/assets/javascripts/discourse/components/poll.gjs#L442)

| Position | Argument  | Type     | Description |
| -------- | --------- | -------- | ----------- |
| 1        | poll1     | variable | -           |
| 2        | this.post | property | -           |
| 3        | this.vote | property | -           |

</details>


### post
#### post:created [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1210)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | createdPost | variable | True           | -           |

#### post:highlight [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/url.js#L356)

| Position | Argument                   | Type     | Always Present | Description |
| -------- | -------------------------- | -------- | -------------- | ----------- |
| 1        | result.payload.post_number | property | True           | -           |
| 2        | options                    | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/url.js#356 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/url.js#L356)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | closest  | variable | -           |

##### /app/assets/javascripts/discourse/app/routes/topic-from-params.js#98 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic-from-params.js#L98)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | closest  | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1213 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1213)

| Position | Argument                   | Type     | Description |
| -------- | -------------------------- | -------- | ----------- |
| 1        | result.payload.post_number | property | -           |
| 2        | options                    | variable | -           |

</details>

#### post:show-revision [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js#L1290)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | copy.postNumber     | property | True           | -           |
| 2        | copy.revisionNumber | property | True           | -           |


### post-stream
#### post-stream:filter-replies [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js#L270)

| Position | Argument               | Type            | Always Present | Description |
| -------- | ---------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1             | object          | True           | -           |
| -        | objectArg1.topic_id    | called_function | True           | -           |
| -        | objectArg1.post_number | variable        | True           | -           |
| -        | objectArg1.post_id     | variable        | True           | -           |

#### post-stream:filter-show-all [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/widgets/post-stream.js#L186)

| Position | Argument                 | Type     | Always Present | Description |
| -------- | ------------------------ | -------- | -------------- | ----------- |
| 1        | this.attrs.streamFilters | property | True           | -           |

#### post-stream:filter-upwards [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js#L299)

| Position | Argument            | Type            | Always Present | Description |
| -------- | ------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1          | object          | True           | -           |
| -        | objectArg1.topic_id | called_function | True           | -           |
| -        | objectArg1.post_id  | variable        | True           | -           |

#### post-stream:gap-expanded [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/widgets/post-gap.js#L32)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | objectArg1         | object   | True           | -           |
| -        | objectArg1.post_id | property | True           | -           |

#### post-stream:posted [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1278)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | staged   | variable | True           | -           |

#### post-stream:refresh [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/invite-panel.js#L340)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | args     | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/invite-panel.js#340 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/invite-panel.js#L340)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/components/invite-panel.js#353 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/invite-panel.js#L353)

| Position | Argument         | Type    | Description |
| -------- | ---------------- | ------- | ----------- |
| 1        | objectArg1       | object  | -           |
| -        | objectArg1.force | boolean | -           |

##### /app/assets/javascripts/discourse/app/components/modal/history.js#190 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/modal/history.js#L190)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | variable | -           |

##### /app/assets/javascripts/discourse/app/components/search-menu.js#304 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/search-menu.js#L304)

| Position | Argument         | Type    | Description |
| -------- | ---------------- | ------- | ----------- |
| 1        | objectArg1       | object  | -           |
| -        | objectArg1.force | boolean | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#112 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L112)

| Position | Argument         | Type    | Description |
| -------- | ---------------- | ------- | ----------- |
| 1        | objectArg1       | object  | -           |
| -        | objectArg1.force | boolean | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#296 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L296)

| Position | Argument         | Type    | Description |
| -------- | ---------------- | ------- | ----------- |
| 1        | objectArg1       | object  | -           |
| -        | objectArg1.force | boolean | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#734 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L734)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/controllers/topic.js#914 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L914)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | variable | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1417 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1417)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1734 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1734)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | args     | variable | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1880 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1880)

| Position | Argument      | Type            | Description |
| -------- | ------------- | --------------- | ----------- |
| 1        | objectArg1    | object          | -           |
| -        | objectArg1.id | called_function | -           |

##### /app/assets/javascripts/discourse/app/lib/flag-targets/flag.js#26 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/flag-targets/flag.js#L26)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#625 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L625)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/post-bookmark-manager.js#60 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/post-bookmark-manager.js#L60)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/models/composer.js#1075 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1075)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/models/composer.js#1087 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1087)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/models/post-stream.js#284 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js#L284)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/models/post-stream.js#304 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js#L304)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/models/post-stream.js#438 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post-stream.js#L438)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/models/post.js#530 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post.js#L530)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1194 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1194)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/services/composer.js#1201 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1201)

| Position | Argument      | Type            | Description |
| -------- | ------------- | --------------- | ----------- |
| 1        | objectArg1    | object          | -           |
| -        | objectArg1.id | called_function | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1208 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1208)

No arguments passed to this event.

</details>


### quote-button
#### quote-button:edit [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L353)

No arguments passed to this event.

#### quote-button:quote [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L337)

No arguments passed to this event.


### sidebar-hamburger-dropdown
#### sidebar-hamburger-dropdown:rendered [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/sidebar/hamburger-dropdown.gjs#L26)

No arguments passed to this event.


### site-header
#### site-header:force-refresh [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/narrow-desktop.js#L26)

No arguments passed to this event.


### this.eventPrefix
#### this.eventPrefix:insert-text [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#L423)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | markdown | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#423 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#L423)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | table    | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#477 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#L477)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | markdown | variable | -           |

</details>


### topic
#### topic:created [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1212)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | createdPost | variable | True           | -           |
| 2        | this        | this     | True           | -           |

#### topic:current-post-changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L513)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | objectArg1      | object   | True           | -           |
| -        | objectArg1.post | variable | True           | -           |

#### topic:current-post-scrolled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L520)

| Position | Argument             | Type            | Always Present | Description |
| -------- | -------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1           | object          | True           | -           |
| -        | objectArg1.postIndex | property        | True           | -           |
| -        | objectArg1.percent   | called_function | True           | -           |

#### topic:jump-to-post [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L965)

| Position | Argument | Type            | Always Present | Description |
| -------- | -------- | --------------- | -------------- | ----------- |
| 1        | this.get | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/controllers/topic.js#965 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L965)

| Position | Argument | Type            | Description |
| -------- | -------- | --------------- | ----------- |
| 1        | this.get | called_function | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1344 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1344)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | postId   | variable | -           |

</details>

#### topic:keyboard-trigger [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L518)

| Position | Argument        | Type   | Always Present | Description |
| -------- | --------------- | ------ | -------------- | ----------- |
| 1        | objectArg1      | object | True           | -           |
| -        | objectArg1.type | string | True           | -           |

#### topic:scrolled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/discourse-topic.js#L99)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | offset   | variable | True           | -           |

#### topic:timings-sent [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/screen-track.js#L209)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | data     | variable | True           | -           |


### topic-entrance
#### topic-entrance:show [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/basic-topic-list.js#L106)

| Position | Argument            | Type            | Always Present | Description |
| -------- | ------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1          | object          | True           | -           |
| -        | objectArg1.topic    | variable        | True           | -           |
| -        | objectArg1.position | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/basic-topic-list.js#106 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/basic-topic-list.js#L106)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | objectArg1          | object          | -           |
| -        | objectArg1.topic    | variable        | -           |
| -        | objectArg1.position | called_function | -           |

##### /app/assets/javascripts/discourse/app/components/featured-topic.js#13 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/featured-topic.js#L13)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | objectArg1          | object          | -           |
| -        | objectArg1.topic    | property        | -           |
| -        | objectArg1.position | called_function | -           |

##### /app/assets/javascripts/discourse/app/components/topic-list-item.js#34 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/topic-list-item.js#L34)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | objectArg1          | object          | -           |
| -        | objectArg1.topic    | property        | -           |
| -        | objectArg1.position | called_function | -           |

</details>


### topic-header
#### topic-header:trigger-this.args.type-card [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/header/topic/participant.gjs#L19)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | this.args.username | property | True           | -           |
| 2        | e1.target          | property | True           | -           |
| 3        | e1                 | variable | True           | -           |


### upload-mixin
#### upload-mixin:this.config.id:all-uploads-complete [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L572)

No arguments passed to this event.

#### upload-mixin:this.config.id:in-progress-uploads [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L382)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | this.inProgressUploads | property | True           | -           |

#### upload-mixin:this.config.id:upload-cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L304)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file.id  | property | True           | -           |

#### upload-mixin:this.config.id:upload-success [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L249)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | file.name        | property | True           | -           |
| 2        | completeResponse | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#249 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L249)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | file.name        | property | -           |
| 2        | completeResponse | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#270 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L270)

| Position | Argument  | Type     | Description |
| -------- | --------- | -------- | ----------- |
| 1        | file.name | property | -           |
| 2        | upload    | variable | -           |

</details>

#### upload-mixin:this.config.id:uploads-cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/uppy-upload.js#L346)

No arguments passed to this event.


### user-card
#### user-card:after-show [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/card-contents-base.js#L93)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | objectArg1      | object   | True           | -           |
| -        | objectArg1.user | variable | True           | -           |

#### user-card:show [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/card-contents-base.js#L88)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1          | object   | True           | -           |
| -        | objectArg1.username | variable | True           | -           |


### user-drafts
#### user-drafts:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/user.js#L1233)

No arguments passed to this event.


### user-menu
#### user-menu:notification-click [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/user-menu/notification-item.js#L85)

| Position | Argument                | Type     | Always Present | Description |
| -------- | ----------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1              | object   | True           | -           |
| -        | objectArg1.notification | property | True           | -           |
| -        | objectArg1.href         | property | True           | -           |

#### user-menu:rendered [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-menu/menu.js#L319)

No arguments passed to this event.

#### user-menu:tab-click [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-menu/menu.js#L313)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | tab.id   | property | True           | -           |


### user-reviewable-count
#### user-reviewable-count:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/user.js#L1238)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | count    | variable | True           | -           |


### user-status
#### user-status:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#L227)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | data     | variable | True           | -           |


### other events
#### click-tracked [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/click-track.js#L98)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | href     | variable | True           | -           |

#### decorate-non-stream-cooked-element [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L501)

| Position | Argument      | Type     | Always Present | Description |
| -------- | ------------- | -------- | -------------- | ----------- |
| 1        | cookedElement | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#501 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L501)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | preview  | variable | -           |

##### /app/assets/javascripts/discourse/app/components/d-editor.js#264 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-editor.js#L264)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | cookedElement | variable | -           |

##### /app/assets/javascripts/discourse/app/components/discourse-banner.js#51 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/discourse-banner.js#L51)

| Position | Argument     | Type     | Description |
| -------- | ------------ | -------- | ----------- |
| 1        | this.element | property | -           |

##### /app/assets/javascripts/discourse/app/components/user-stream.js#50 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-stream.js#L50)

| Position | Argument     | Type     | Description |
| -------- | ------------ | -------- | ----------- |
| 1        | this.element | property | -           |

##### /app/assets/javascripts/discourse/app/components/user-stream.js#149 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-stream.js#L149)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | element  | variable | -           |

</details>

#### desktop-notification-opened [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/desktop-notifications.js#L179)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | objectArg1     | object   | True           | -           |
| -        | objectArg1.url | property | True           | -           |

#### keyboard-visibility-change [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-virtual-height.gjs#L87)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | keyboardVisible | variable | True           | -           |

#### push-notification-opened [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/push-notifications.js#L77)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | objectArg1     | object   | True           | -           |
| -        | objectArg1.url | property | True           | -           |

#### REFRESH_USER_SIDEBAR_CATEGORIES_SECTION_COUNTS_APP_EVENT_NAME [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs#L2368)

No arguments passed to this event.

#### this.flagCreatedEvent [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/flag-targets/flag.js#L15)

| Position | Argument                       | Type     | Always Present | Description |
| -------- | ------------------------------ | -------- | -------------- | ----------- |
| 1        | flagModal.args.model.flagModel | property | True           | -           |
| 2        | postAction                     | variable | True           | -           |
| 3        | opts                           | variable | True           | -           |


