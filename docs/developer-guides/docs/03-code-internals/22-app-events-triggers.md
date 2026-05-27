---
title: AppEvents Triggers Reference
short_title: AppEvents Triggers
id: app-events-triggers
---

<div data-theme-toc="true"> </div>

# AppEvents

The AppEvent system in Discourse provides a pub/sub mechanism for handling UI updates and component interactions - and these events are triggered via calls of `AppEvent.trigger`.

This topic consolidates a list of all such event triggers and their arguments, along with line-of-code references to the Discourse source code.

## How to figure out what happens on an event trigger

AppEvent is based on the Ember's Evented class, and similarly, events are handled by [the `on` method](https://api.emberjs.com/ember/5.12/classes/Evented/methods/on?anchor=on).

Once the specific AppEvent trigger is identified, you may search in the source code for the corresponding `.on` method with the event name as the first argument.

This method should have an event handler function passed in as the last argument for executing any necessary logic upon trigger of the event.

Taking the `composer:open` event, we can search for `appEvents.on("composer:open"`. This could lead us to 1 or more places in the code where the event is handled. Each of these would execute a callback function whenever the event is triggered, for example:

```
    this.appEvents.on("composer:opened", this, this._findMessages);
```

You would then refer to the definition of the callback function `this._findMessages` to understand what happens when the `composer:opened` event is triggered. This callback function can take in arguments passed in from the trigger of the event to be processed within the scope of the function.

## List of AppEvent Triggers

### ace

#### ace:resize [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/admin/components/admin-theme-editor.gjs#L118)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /frontend/discourse/admin/components/admin-theme-editor.gjs#118 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/admin/components/admin-theme-editor.gjs#L118)

No arguments passed to this event.

##### /plugins/discourse-data-explorer/assets/javascripts/discourse/controllers/admin-plugins/explorer/index.js#119 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-data-explorer/assets/javascripts/discourse/controllers/admin-plugins/explorer/index.js#L119)

No arguments passed to this event.

##### /plugins/discourse-data-explorer/assets/javascripts/discourse/controllers/admin-plugins/explorer/queries/details.js#137 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-data-explorer/assets/javascripts/discourse/controllers/admin-plugins/explorer/queries/details.js#L137)

No arguments passed to this event.

</details>

### bookmarks

#### bookmarks:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/bookmark-list.gjs#L54)

| Position | Argument                      | Type            | Always Present | Description |
| -------- | ----------------------------- | --------------- | -------------- | ----------- |
| 1        | bookmarkFormData.saveData     | property        | True           | -           |
| 2        | this.bookmarkModel.attachedTo | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/components/bookmark-list.gjs#54 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/bookmark-list.gjs#L54)

| Position | Argument             | Type            | Description |
| -------- | -------------------- | --------------- | ----------- |
| 1        | null                 | null            | -           |
| 2        | bookmark1.attachedTo | called_function | -           |

##### /frontend/discourse/app/components/bookmark-list.gjs#85 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/bookmark-list.gjs#L85)

| Position | Argument             | Type            | Description |
| -------- | -------------------- | --------------- | ----------- |
| 1        | savedData1           | variable        | -           |
| 2        | bookmark1.attachedTo | called_function | -           |

##### /frontend/discourse/app/controllers/topic.js#1510 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L1510)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

##### /frontend/discourse/app/lib/topic-bookmark-manager.js#57 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/topic-bookmark-manager.js#L57)

| Position | Argument                      | Type            | Description |
| -------- | ----------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData     | property        | -           |
| 2        | this.bookmarkModel.attachedTo | called_function | -           |

##### /frontend/discourse/app/models/post.js#688 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/post.js#L688)

| Position | Argument            | Type     | Description |
| -------- | ------------------- | -------- | ----------- |
| 1        | data                | variable | -           |
| 2        | objectArg2          | object   | -           |
| -        | objectArg2.target   | string   | -           |
| -        | objectArg2.targetId | property | -           |

##### /frontend/discourse/app/models/post.js#708 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/post.js#L708)

| Position | Argument            | Type     | Description |
| -------- | ------------------- | -------- | ----------- |
| 1        | null                | null     | -           |
| 2        | objectArg2          | object   | -           |
| -        | objectArg2.target   | string   | -           |
| -        | objectArg2.targetId | property | -           |

##### /frontend/discourse/app/models/topic.js#715 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/topic.js#L715)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | null                | null            | -           |
| 2        | bookmark.attachedTo | called_function | -           |

##### /plugins/chat/assets/javascripts/discourse/lib/chat-message-interactor.js#374 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/lib/chat-message-interactor.js#L374)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

##### /plugins/discourse-data-explorer/assets/javascripts/discourse/controllers/group/reports/show.js#121 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-data-explorer/assets/javascripts/discourse/controllers/group/reports/show.js#L121)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

</details>

### calendar

#### calendar:create-invitee-status [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/assets/javascripts/discourse/components/discourse-post-event/status.gjs#L70)

| Position | Argument          | Type     | Always Present | Description |
| -------- | ----------------- | -------- | -------------- | ----------- |
| 1        | objectArg1        | object   | True           | -           |
| -        | objectArg1.status | variable | True           | -           |
| -        | objectArg1.postId | property | True           | -           |

#### calendar:invitee-left-event [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/assets/javascripts/discourse/components/discourse-post-event/status.gjs#L42)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | objectArg1         | object   | True           | -           |
| -        | objectArg1.invitee | variable | True           | -           |
| -        | objectArg1.postId  | property | True           | -           |

#### calendar:update-invitee-status [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/assets/javascripts/discourse/components/discourse-post-event/status.gjs#L56)

| Position | Argument          | Type     | Always Present | Description |
| -------- | ----------------- | -------- | -------------- | ----------- |
| 1        | objectArg1        | object   | True           | -           |
| -        | objectArg1.status | variable | True           | -           |
| -        | objectArg1.postId | property | True           | -           |

### card

#### card:close [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat/direct-message-button.gjs#L32)

No arguments passed to this event.

#### card:hide [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/card-contents-base.js#L270)

No arguments passed to this event.

#### card:show [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/card-contents-base.js#L64)

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

#### chat:modify-selection [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L77)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | event              | variable | True           | -           |
| 2        | objectArg2         | object   | True           | -           |
| -        | objectArg2.type    | variable | True           | -           |
| -        | objectArg2.context | property | True           | -           |

#### chat:open-insert-link-modal [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L89)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | event              | variable | True           | -           |
| 2        | objectArg2         | object   | True           | -           |
| -        | objectArg2.context | property | True           | -           |

#### chat:open-url [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/routes/chat.js#L66)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | url      | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/chat/assets/javascripts/discourse/routes/chat.js#66 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/routes/chat.js#L66)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | url      | variable | -           |

##### /plugins/chat/assets/javascripts/discourse/routes/chat.js#71 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/routes/chat.js#L71)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | url      | variable | -           |

</details>

#### chat:refresh-channel-members [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat-subscriptions-manager.js#L467)

No arguments passed to this event.

#### chat:rerender-header [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-drawer.gjs#L79)

No arguments passed to this event.

#### chat:toggle-close [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L117)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | event    | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#117 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/initializers/chat-keyboard-shortcuts.js#L117)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | event    | variable | -           |

##### /plugins/chat/assets/javascripts/discourse/routes/chat.js#76 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/routes/chat.js#L76)

No arguments passed to this event.

</details>

#### chat:toggle-expand [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-drawer.gjs#L163)

| Position | Argument                               | Type     | Always Present | Description |
| -------- | -------------------------------------- | -------- | -------------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/chat/assets/javascripts/discourse/components/chat-drawer.gjs#163 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat-drawer.gjs#L163)

| Position | Argument                               | Type     | Description |
| -------- | -------------------------------------- | -------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | -           |

##### /plugins/chat/assets/javascripts/discourse/services/chat.js#437 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat.js#L437)

| Position | Argument                               | Type     | Description |
| -------- | -------------------------------------- | -------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | -           |

</details>

### composer

#### composer:add-files [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/static/prosemirror/extensions/image.js#L438)

| Position | Argument                   | Type      | Always Present | Description |
| -------- | -------------------------- | --------- | -------------- | ----------- |
| 1        | undefined                  | undefined | True           | -           |
| 2        | objectArg2                 | object    | True           | -           |
| -        | objectArg2.skipPlaceholder | boolean   | True           | -           |

#### composer:cancel-upload [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L673)

No arguments passed to this event.

#### composer:cancelled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1654)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/services/composer.js#1654 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1654)

No arguments passed to this event.

##### /frontend/discourse/app/services/composer.js#1669 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1669)

No arguments passed to this event.

##### /frontend/discourse/app/services/composer.js#1686 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1686)

No arguments passed to this event.

</details>

#### composer:created-post [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1208)

| Position | Argument          | Type     | Always Present | Description |
| -------- | ----------------- | -------- | -------------- | ----------- |
| 1        | objectArg1        | object   | True           | -           |
| -        | objectArg1.postId | property | True           | -           |

#### composer:div-resizing [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-container.gjs#L55)

No arguments passed to this event.

#### composer:edited-post [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1201)

No arguments passed to this event.

#### composer:find-similar [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-body.js#L57)

No arguments passed to this event.

#### composer:insert-block [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L535)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | template.content | property | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/controllers/topic.js#535 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L535)

| Position | Argument   | Type     | Description |
| -------- | ---------- | -------- | ----------- |
| 1        | quotedText | variable | -           |

##### /frontend/discourse/app/controllers/topic.js#777 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L777)

| Position | Argument        | Type            | Description |
| -------- | --------------- | --------------- | ----------- |
| 1        | quotedText.trim | called_function | -           |

##### /frontend/discourse/app/lib/lightbox/quote-image.js#89 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/lightbox/quote-image.js#L89)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | quote    | variable | -           |

##### /plugins/discourse-templates/assets/javascripts/discourse/services/d-templates.js#103 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-templates/assets/javascripts/discourse/services/d-templates.js#L103)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | template.content | property | -           |

</details>

#### composer:insert-text [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/search.js#L61)

| Position | Argument                    | Type     | Always Present | Description |
| -------- | --------------------------- | -------- | -------------- | ----------- |
| 1        | document.activeElement.href | property | True           | -           |
| 2        | objectArg2                  | object   | True           | -           |
| -        | objectArg2.ensureSpace      | boolean  | True           | -           |

#### composer:open [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1467)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.model | property | True           | -           |

#### composer:opened [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-body.js#L81)

No arguments passed to this event.

#### composer:preview-toggled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L163)

| Position | Argument              | Type     | Always Present | Description |
| -------- | --------------------- | -------- | -------------- | ----------- |
| 1        | this.isPreviewVisible | property | True           | -           |

#### composer:replace-text [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/services/image-caption-popup.js#L29)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | match       | variable | True           | -           |
| 2        | replacement | variable | True           | -           |

#### composer:reply-reloaded [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/composer.js#L1011)

| Position | Argument | Type | Always Present | Description |
| -------- | -------- | ---- | -------------- | ----------- |
| 1        | this     | this | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/models/composer.js#1011 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/composer.js#L1011)

| Position | Argument | Type | Description |
| -------- | -------- | ---- | ----------- |
| 1        | this     | this | -           |

##### /frontend/discourse/app/models/composer.js#1030 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/composer.js#L1030)

| Position | Argument | Type | Description |
| -------- | -------- | ---- | ----------- |
| 1        | this     | this | -           |

</details>

#### composer:resize-ended [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-container.gjs#L66)

No arguments passed to this event.

#### composer:resize-started [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-container.gjs#L51)

No arguments passed to this event.

#### composer:resized [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-body.js#L73)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/components/composer-body.js#73 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-body.js#L73)

No arguments passed to this event.

##### /frontend/discourse/app/components/composer-container.gjs#72 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-container.gjs#L72)

No arguments passed to this event.

</details>

#### composer:saved [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1183)

No arguments passed to this event.

#### composer:show-preview [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-templates/assets/javascripts/discourse/services/d-templates.js#L71)

No arguments passed to this event.

#### composer:toolbar-popup-menu-button-clicked [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L702)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | menuItem | variable | True           | -           |

#### composer:typed-reply [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1324)

No arguments passed to this event.

#### this.composerEventPrefix:all-uploads-complete [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L397)

No arguments passed to this event.

#### this.composerEventPrefix:apply-surround [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L614)

| Position | Argument                | Type    | Always Present | Description |
| -------- | ----------------------- | ------- | -------------- | ----------- |
| 1        | [grid]                  | string  | True           | -           |
| 2        | [/grid]                 | string  | True           | -           |
| 3        | grid_surround           | string  | True           | -           |
| 4        | objectArg4              | object  | True           | -           |
| -        | objectArg4.useBlockMode | boolean | True           | -           |

#### this.composerEventPrefix:closed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L188)

No arguments passed to this event.

#### this.composerEventPrefix:replace-text [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L511)

| Position | Argument                    | Type     | Always Present | Description |
| -------- | --------------------------- | -------- | -------------- | ----------- |
| 1        | matchingPlaceholder1.index1 | property | True           | -           |
| 2        | replacement1                | variable | True           | -           |
| 3        | objectArg3                  | object   | False          | -           |
| -        | objectArg3.regex            | variable | False          | -           |
| -        | objectArg3.index            | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/components/composer-editor.gjs#511 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L511)

| Position | Argument                    | Type     | Description |
| -------- | --------------------------- | -------- | ----------- |
| 1        | matchingPlaceholder1.index1 | property | -           |
| 2        | replacement1                | variable | -           |
| 3        | objectArg3                  | object   | -           |
| -        | objectArg3.regex            | variable | -           |
| -        | objectArg3.index            | variable | -           |

##### /frontend/discourse/app/components/composer-editor.gjs#537 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L537)

| Position | Argument     | Type     | Description |
| -------- | ------------ | -------- | ----------- |
| 1        | match1       | variable | -           |
| 2        | replacement1 | variable | -           |

##### /frontend/discourse/app/components/composer-editor.gjs#597 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L597)

| Position | Argument                    | Type     | Description |
| -------- | --------------------------- | -------- | ----------- |
| 1        | matchingPlaceholder1.index1 | property | -           |
| 2        | string                      | string   | -           |
| 3        | objectArg3                  | object   | -           |
| -        | objectArg3.regex            | variable | -           |
| -        | objectArg3.index            | variable | -           |

</details>

#### this.composerEventPrefix:upload-cancelled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L288)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file.id  | property | True           | -           |

#### this.composerEventPrefix:upload-error [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L439)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file     | variable | True           | -           |

#### this.composerEventPrefix:upload-started [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L345)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | file.name | property | True           | -           |

#### this.composerEventPrefix:upload-success [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L390)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | file.name | property | True           | -           |
| 2        | upload    | variable | True           | -           |

#### this.composerEventPrefix:uploads-aborted [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L132)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/lib/uppy/composer-upload.js#132 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L132)

No arguments passed to this event.

##### /frontend/discourse/app/lib/uppy/composer-upload.js#181 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L181)

No arguments passed to this event.

</details>

#### this.composerEventPrefix:uploads-cancelled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L418)

No arguments passed to this event.

#### this.composerEventPrefix:uploads-preprocessing-complete [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/composer-upload.js#L514)

No arguments passed to this event.

#### this.composerEventPrefix:will-close [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L186)

No arguments passed to this event.

#### this.composerEventPrefix:will-open [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/composer-editor.gjs#L182)

No arguments passed to this event.

### composer-messages

#### composer-messages:close [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L918)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/services/composer.js#918 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L918)

No arguments passed to this event.

##### /plugins/discourse-templates/assets/javascripts/discourse/services/d-templates.js#70 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-templates/assets/javascripts/discourse/services/d-templates.js#L70)

No arguments passed to this event.

</details>

#### composer-messages:create [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L794)

| Position | Argument                | Type            | Always Present | Description |
| -------- | ----------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1              | object          | True           | -           |
| -        | objectArg1.extraClass   | string          | True           | -           |
| -        | objectArg1.templateName | string          | True           | -           |
| -        | objectArg1.body         | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/services/composer.js#794 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L794)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /frontend/discourse/app/services/composer.js#804 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L804)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /frontend/discourse/app/services/composer.js#969 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L969)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

##### /frontend/discourse/app/services/composer.js#993 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L993)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

##### /frontend/discourse/app/services/composer.js#1002 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1002)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /frontend/discourse/app/static/prosemirror/extensions/mention.js#251 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/static/prosemirror/extensions/mention.js#L251)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

</details>

### composer-service

#### composer-service:last-validated-at-cleared [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1855)

No arguments passed to this event.

#### composer-service:last-validated-at-updated [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1073)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.model | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/services/composer.js#1073 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1073)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.model | variable | -           |

##### /frontend/discourse/app/services/composer.js#1282 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1282)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.model | property | -           |

</details>

### count-updated

#### count-updated:user.username_lower:key [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/routes/user.js#L102)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | value    | variable | True           | -           |

### cta

#### cta:shown [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/signup-cta.js#L67)

No arguments passed to this event.

### d-editor

#### d-editor:preview-click-group-card [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/d-editor-preview.gjs#L23)

| Position | Argument      | Type     | Always Present | Description |
| -------- | ------------- | -------- | -------------- | ----------- |
| 1        | event1.target | property | True           | -           |
| 2        | event1        | variable | True           | -           |

#### d-editor:preview-click-user-card [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/d-editor-preview.gjs#L20)

| Position | Argument      | Type     | Always Present | Description |
| -------- | ------------- | -------- | -------------- | ----------- |
| 1        | event1.target | property | True           | -           |
| 2        | event1        | variable | True           | -           |

### destroyed-custom-html

#### destroyed-custom-html:this.name [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/custom-html.js#L41)

No arguments passed to this event.

### discourse

#### discourse:focus-changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/document-title.js#L40)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | session.hasFocus | property | True           | -           |

### discourse-ai

#### discourse-ai:bot-header-icon-clicked [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/components/ai-bot-header-icon.gjs#L55)

No arguments passed to this event.

#### discourse-ai:bot-pm-created [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/services/ai-bot-conversations-hidden-submit.js#L86)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.id    | property | True           | -           |
| -        | objectArg1.slug  | property | True           | -           |
| -        | objectArg1.title | variable | True           | -           |

#### discourse-ai:force-conversations-sidebar [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/services/ai-conversations-sidebar-manager.js#L105)

No arguments passed to this event.

#### discourse-ai:new-conversation-btn-clicked [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/components/ai-bot-sidebar-new-conversation.gjs#L30)

No arguments passed to this event.

#### discourse-ai:stop-forcing-conversations-sidebar [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/services/ai-conversations-sidebar-manager.js#L166)

No arguments passed to this event.

### discourse-reactions

#### discourse-reactions:reaction-toggled [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-reactions/assets/javascripts/discourse/models/discourse-reactions-custom-reaction.js#L15)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1          | object   | True           | -           |
| -        | objectArg1.post     | variable | True           | -           |
| -        | objectArg1.reaction | property | True           | -           |

### discourse-solved

#### discourse-solved:solution-toggled [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-solved/assets/javascripts/discourse/components/solved-accept-answer-button.gjs#L28)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | post1    | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/discourse-solved/assets/javascripts/discourse/components/solved-accept-answer-button.gjs#28 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-solved/assets/javascripts/discourse/components/solved-accept-answer-button.gjs#L28)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | post1    | variable | -           |

##### /plugins/discourse-solved/assets/javascripts/discourse/components/solved-unaccept-answer-button.gjs#28 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-solved/assets/javascripts/discourse/components/solved-unaccept-answer-button.gjs#L28)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | post1    | variable | -           |

</details>

### discourse-templates

#### discourse-templates:show [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-templates/assets/javascripts/discourse/services/d-templates.js#L72)

| Position | Argument                    | Type     | Always Present | Description |
| -------- | --------------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1                  | object   | True           | -           |
| -        | objectArg1.onInsertTemplate | variable | True           | -           |

### do-not-disturb

#### do-not-disturb:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/user.js#L1291)

| Position | Argument                  | Type     | Always Present | Description |
| -------- | ------------------------- | -------- | -------------- | ----------- |
| 1        | this.do_not_disturb_until | property | True           | -           |

### dom

#### dom:clean [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/clean-dom-on-route-change.js#L35)

No arguments passed to this event.

### draft

#### draft:destroyed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1635)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | key      | variable | True           | -           |

### emoji-picker

#### emoji-picker:close [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L913)

No arguments passed to this event.

### flag

#### flag:created [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/modal/flag.gjs#L177)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | objectArg1         | object   | True           | -           |
| -        | objectArg1.message | property | True           | -           |
| -        | objectArg1.postId  | property | True           | -           |

### full-page-search

#### full-page-search:trigger-search [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/full-page-search.js#L599)

No arguments passed to this event.

### group

#### group:join [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/group-membership-button.gjs#L53)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | group1   | variable | True           | -           |

#### group:leave [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/group-membership-button.gjs#L41)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | model1   | variable | True           | -           |

### header

#### header:hide-topic [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/routes/topic.js#L403)

No arguments passed to this event.

#### header:keyboard-trigger [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L531)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.type  | string   | True           | -           |
| -        | objectArg1.event | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/services/keyboard-shortcuts.js#531 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L531)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /frontend/discourse/app/services/keyboard-shortcuts.js#540 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L540)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /frontend/discourse/app/services/keyboard-shortcuts.js#547 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L547)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /frontend/discourse/app/services/search.js#68 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/search.js#L68)

| Position | Argument        | Type   | Description |
| -------- | --------------- | ------ | ----------- |
| 1        | objectArg1      | object | -           |
| -        | objectArg1.type | string | -           |

</details>

#### header:show-topic [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/modal/convert-to-public-topic.gjs#L31)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic1   | variable | True           | -           |

#### header:update-topic [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L1843)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | composer.topic | property | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/controllers/topic.js#1843 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L1843)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | topic    | variable | -           |

##### /frontend/discourse/app/instance-initializers/subscribe-user-notifications.js#168 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/subscribe-user-notifications.js#L168)

| Position | Argument | Type    | Description |
| -------- | -------- | ------- | ----------- |
| 1        | null     | null    | -           |
| 2        | 5000     | integer | -           |

##### /frontend/discourse/app/routes/topic.js#428 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/routes/topic.js#L428)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | model    | variable | -           |

##### /frontend/discourse/app/services/composer.js#1203 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1203)

| Position | Argument       | Type     | Description |
| -------- | -------------- | -------- | ----------- |
| 1        | composer.topic | property | -           |

##### /plugins/discourse-assign/assets/javascripts/discourse/initializers/extend-for-assigns.js#502 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-assign/assets/javascripts/discourse/initializers/extend-for-assigns.js#L502)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | topic    | variable | -           |

</details>

### inserted-custom-html

#### inserted-custom-html:this.name [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/custom-html.js#L34)

No arguments passed to this event.

### interface-color

#### interface-color:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/interface-color.js#L95)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | LIGHT_VALUE_FOR_COOKIE | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/services/interface-color.js#95 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/interface-color.js#L95)

| Position | Argument               | Type     | Description |
| -------- | ---------------------- | -------- | ----------- |
| 1        | LIGHT_VALUE_FOR_COOKIE | variable | -           |

##### /frontend/discourse/app/services/interface-color.js#113 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/interface-color.js#L113)

| Position | Argument              | Type     | Description |
| -------- | --------------------- | -------- | ----------- |
| 1        | DARK_VALUE_FOR_COOKIE | variable | -           |

##### /frontend/discourse/app/services/interface-color.js#127 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/interface-color.js#L127)

| Position | Argument               | Type     | Description |
| -------- | ---------------------- | -------- | ----------- |
| 1        | LIGHT_VALUE_FOR_COOKIE | variable | -           |

##### /frontend/discourse/app/services/interface-color.js#136 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/interface-color.js#L136)

| Position | Argument              | Type     | Description |
| -------- | --------------------- | -------- | ----------- |
| 1        | DARK_VALUE_FOR_COOKIE | variable | -           |

</details>

### keyboard

#### keyboard:move-selection [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L792)

| Position | Argument                   | Type     | Always Present | Description |
| -------- | -------------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1                 | object   | True           | -           |
| -        | objectArg1.articles        | variable | True           | -           |
| -        | objectArg1.selectedArticle | variable | True           | -           |

### notifications

#### notifications:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/subscribe-user-notifications.js#L160)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/instance-initializers/subscribe-user-notifications.js#160 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/subscribe-user-notifications.js#L160)

No arguments passed to this event.

##### /plugins/chat/assets/javascripts/discourse/services/chat-tracking-state-manager.js#110 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat-tracking-state-manager.js#L110)

No arguments passed to this event.

</details>

### page

#### page:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/page-tracker.js#L42)

| Position | Argument                           | Type            | Always Present | Description |
| -------- | ---------------------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1                         | object          | True           | -           |
| -        | objectArg1.url                     | variable        | True           | -           |
| -        | objectArg1.title                   | called_function | False          | -           |
| -        | objectArg1.currentRouteName        | property        | False          | -           |
| -        | objectArg1.replacedOnlyQueryParams | variable        | False          | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/lib/page-tracker.js#42 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/page-tracker.js#L42)

| Position | Argument                           | Type            | Description |
| -------- | ---------------------------------- | --------------- | ----------- |
| 1        | objectArg1                         | object          | -           |
| -        | objectArg1.url                     | variable        | -           |
| -        | objectArg1.title                   | called_function | -           |
| -        | objectArg1.currentRouteName        | property        | -           |
| -        | objectArg1.replacedOnlyQueryParams | variable        | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#37 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L37)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#53 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L53)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#93 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L93)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#124 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L124)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#141 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L141)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#153 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L153)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#172 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L172)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#201 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L201)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#218 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L218)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

##### /plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#239 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-calendar/test/javascripts/integration/components/upcoming-events-list-test.gjs#L239)

| Position | Argument       | Type   | Description |
| -------- | -------------- | ------ | ----------- |
| 1        | objectArg1     | object | -           |
| -        | objectArg1.url | string | -           |

</details>

#### page:compose-reply [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L755)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic    | variable | True           | -           |

#### page:like-toggled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/post.gjs#L237)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | post1       | variable | True           | -           |
| 2        | likeAction1 | variable | True           | -           |

#### page:topic-loaded [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/routes/topic/from-params.js#L94)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic    | variable | True           | -           |

### policy

#### policy:changed [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-policy/assets/javascripts/discourse/initializers/extend-for-policy.gjs#L89)

| Position | Argument              | Type     | Always Present | Description |
| -------- | --------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1            | object   | True           | -           |
| -        | objectArg1.controller | variable | True           | -           |
| -        | objectArg1.message    | variable | True           | -           |

### poll

#### poll:voted [:link:](https://github.com/discourse/discourse/blob/main/plugins/poll/assets/javascripts/discourse/components/poll.gjs#L190)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | poll1     | variable | True           | -           |
| 2        | this.post | property | True           | -           |
| 3        | this.vote | property | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/poll/assets/javascripts/discourse/components/poll.gjs#190 [:link:](https://github.com/discourse/discourse/blob/main/plugins/poll/assets/javascripts/discourse/components/poll.gjs#L190)

| Position | Argument  | Type     | Description |
| -------- | --------- | -------- | ----------- |
| 1        | poll1     | variable | -           |
| 2        | this.post | property | -           |
| 3        | this.vote | property | -           |

##### /plugins/poll/assets/javascripts/discourse/components/poll.gjs#448 [:link:](https://github.com/discourse/discourse/blob/main/plugins/poll/assets/javascripts/discourse/components/poll.gjs#L448)

| Position | Argument  | Type     | Description |
| -------- | --------- | -------- | ----------- |
| 1        | poll1     | variable | -           |
| 2        | this.post | property | -           |
| 3        | this.vote | property | -           |

</details>

### post

#### post:created [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/composer.js#L1276)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | createdPost | variable | True           | -           |

#### post:highlight [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/url.js#L366)

| Position | Argument                   | Type     | Always Present | Description |
| -------- | -------------------------- | -------- | -------------- | ----------- |
| 1        | result.payload.post_number | property | True           | -           |
| 2        | options                    | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/lib/url.js#366 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/url.js#L366)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | closest  | variable | -           |

##### /frontend/discourse/app/routes/topic/from-params.js#99 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/routes/topic/from-params.js#L99)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | closest  | variable | -           |

##### /frontend/discourse/app/services/composer.js#1211 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/composer.js#L1211)

| Position | Argument                   | Type     | Description |
| -------- | -------------------------- | -------- | ----------- |
| 1        | result.payload.post_number | property | -           |
| 2        | options                    | variable | -           |

</details>

#### post:show-revision [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/post-stream.js#L1306)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | copy.postNumber     | property | True           | -           |
| 2        | copy.revisionNumber | property | True           | -           |

### post-stream

#### post-stream:filter-replies [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/post-stream.js#L278)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1             | object   | True           | -           |
| -        | objectArg1.topic_id    | property | True           | -           |
| -        | objectArg1.post_number | variable | True           | -           |
| -        | objectArg1.post_id     | variable | True           | -           |

#### post-stream:filter-show-all [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/post/filtered-notice.gjs#L111)

| Position | Argument                | Type     | Always Present | Description |
| -------- | ----------------------- | -------- | -------------- | ----------- |
| 1        | this.args.streamFilters | property | True           | -           |

#### post-stream:filter-upwards [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/post-stream.js#L305)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1          | object   | True           | -           |
| -        | objectArg1.topic_id | property | True           | -           |
| -        | objectArg1.post_id  | variable | True           | -           |

#### post-stream:gap-expanded [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/post/gap.gjs#L26)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | objectArg1         | object   | True           | -           |
| -        | objectArg1.post_id | property | True           | -           |

### quote-button

#### quote-button:edit [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L355)

No arguments passed to this event.

#### quote-button:quote [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L339)

No arguments passed to this event.

### reviewablenote

#### reviewablenote:created [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/reviewable-refresh/note-form.gjs#L62)

| Position | Argument             | Type     | Always Present | Description |
| -------- | -------------------- | -------- | -------------- | ----------- |
| 1        | data1                | variable | True           | -           |
| 2        | this.args.reviewable | property | True           | -           |
| 3        | this.formApi         | property | True           | -           |

### search

#### search:search_result_view [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/full-page-search.js#L491)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | objectArg1      | object   | True           | -           |
| -        | objectArg1.page | property | True           | -           |

### search-menu

#### search-menu:search_menu_opened [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/search-menu.gjs#L137)

No arguments passed to this event.

### sidebar-hamburger-dropdown

#### sidebar-hamburger-dropdown:rendered [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/sidebar/hamburger-dropdown.gjs#L25)

No arguments passed to this event.

### site-header

#### site-header:force-refresh [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/narrow-desktop.js#L26)

No arguments passed to this event.

### this.eventPrefix

#### this.eventPrefix:insert-text [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/textarea-text-manipulation.js#L447)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | markdown | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/lib/textarea-text-manipulation.js#447 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/textarea-text-manipulation.js#L447)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | table    | variable | -           |

##### /frontend/discourse/app/lib/textarea-text-manipulation.js#501 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/textarea-text-manipulation.js#L501)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | markdown | variable | -           |

</details>

### topic

#### topic:created [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/composer.js#L1278)

| Position | Argument    | Type     | Always Present | Description |
| -------- | ----------- | -------- | -------------- | ----------- |
| 1        | createdPost | variable | True           | -           |
| 2        | this        | this     | True           | -           |

#### topic:current-post-changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L585)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | objectArg1      | object   | True           | -           |
| -        | objectArg1.post | variable | True           | -           |

#### topic:current-post-scrolled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L592)

| Position | Argument             | Type            | Always Present | Description |
| -------- | -------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1           | object          | True           | -           |
| -        | objectArg1.postIndex | property        | True           | -           |
| -        | objectArg1.percent   | called_function | True           | -           |

#### topic:jump-to-post [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L1085)

| Position | Argument | Type            | Always Present | Description |
| -------- | -------- | --------------- | -------------- | ----------- |
| 1        | this.get | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/controllers/topic.js#1085 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L1085)

| Position | Argument | Type            | Description |
| -------- | -------- | --------------- | ----------- |
| 1        | this.get | called_function | -           |

##### /frontend/discourse/app/controllers/topic.js#1478 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/controllers/topic.js#L1478)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | postId   | variable | -           |

</details>

#### topic:keyboard-trigger [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/keyboard-shortcuts.js#L527)

| Position | Argument        | Type   | Always Present | Description |
| -------- | --------------- | ------ | -------------- | ----------- |
| 1        | objectArg1      | object | True           | -           |
| -        | objectArg1.type | string | True           | -           |

#### topic:scrolled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/discourse-topic.js#L102)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | offset   | variable | True           | -           |

#### topic:timings-sent [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/services/screen-track.js#L208)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | data     | variable | True           | -           |

### topic-entrance

#### topic-entrance:show [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/basic-topic-list.gjs#L89)

| Position | Argument            | Type            | Always Present | Description |
| -------- | ------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1          | object          | True           | -           |
| -        | objectArg1.topic    | variable        | True           | -           |
| -        | objectArg1.position | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/components/basic-topic-list.gjs#89 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/basic-topic-list.gjs#L89)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | objectArg1          | object          | -           |
| -        | objectArg1.topic    | variable        | -           |
| -        | objectArg1.position | called_function | -           |

##### /frontend/discourse/app/components/featured-topic.gjs#14 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/featured-topic.gjs#L14)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | objectArg1          | object          | -           |
| -        | objectArg1.topic    | property        | -           |
| -        | objectArg1.position | called_function | -           |

##### /frontend/discourse/app/components/mobile-category-topic.gjs#19 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/mobile-category-topic.gjs#L19)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | objectArg1          | object          | -           |
| -        | objectArg1.topic    | property        | -           |
| -        | objectArg1.position | called_function | -           |

</details>

### topic-header

#### topic-header:trigger-this.args.type-card [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/header/topic/participant.gjs#L19)

| Position | Argument           | Type     | Always Present | Description |
| -------- | ------------------ | -------- | -------------- | ----------- |
| 1        | this.args.username | property | True           | -           |
| 2        | e1.target          | property | True           | -           |
| 3        | e1                 | variable | True           | -           |

### upload-mixin

#### upload-mixin:this.config.id:all-uploads-complete [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L575)

No arguments passed to this event.

#### upload-mixin:this.config.id:in-progress-uploads [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L385)

| Position | Argument               | Type     | Always Present | Description |
| -------- | ---------------------- | -------- | -------------- | ----------- |
| 1        | this.inProgressUploads | property | True           | -           |

#### upload-mixin:this.config.id:upload-cancelled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L307)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file.id  | property | True           | -           |

#### upload-mixin:this.config.id:upload-success [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L252)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | file.name        | property | True           | -           |
| 2        | completeResponse | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /frontend/discourse/app/lib/uppy/uppy-upload.js#252 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L252)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | file.name        | property | -           |
| 2        | completeResponse | variable | -           |

##### /frontend/discourse/app/lib/uppy/uppy-upload.js#273 [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L273)

| Position | Argument  | Type     | Description |
| -------- | --------- | -------- | ----------- |
| 1        | file.name | property | -           |
| 2        | upload    | variable | -           |

</details>

#### upload-mixin:this.config.id:uploads-cancelled [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/uppy/uppy-upload.js#L349)

No arguments passed to this event.

### user-card

#### user-card:after-show [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/card-contents-base.js#L94)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | objectArg1      | object   | True           | -           |
| -        | objectArg1.user | variable | True           | -           |

#### user-card:show [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/card-contents-base.js#L89)

| Position | Argument            | Type     | Always Present | Description |
| -------- | ------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1          | object   | True           | -           |
| -        | objectArg1.username | variable | True           | -           |

### user-drafts

#### user-drafts:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/user.js#L1297)

No arguments passed to this event.

### user-menu

#### user-menu:notification-click [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/user-menu/notification-item.js#L91)

| Position | Argument                | Type     | Always Present | Description |
| -------- | ----------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1              | object   | True           | -           |
| -        | objectArg1.notification | property | True           | -           |
| -        | objectArg1.href         | property | True           | -           |

#### user-menu:rendered [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/user-menu/menu.gjs#L267)

No arguments passed to this event.

#### user-menu:tab-click [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/user-menu/menu.gjs#L262)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | tab1.id  | property | True           | -           |

### user-reviewable-count

#### user-reviewable-count:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/models/user.js#L1302)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | count    | variable | True           | -           |

### user-status

#### user-status:changed [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/instance-initializers/subscribe-user-notifications.js#L233)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | data     | variable | True           | -           |

### other events

#### AI_RESULTS_TOGGLED [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#L67)

| Position | Argument           | Type    | Always Present | Description |
| -------- | ------------------ | ------- | -------------- | ----------- |
| 1        | objectArg1         | object  | True           | -           |
| -        | objectArg1.enabled | boolean | True           | -           |

<details><summary>Detailed List</summary>

##### /plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#67 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#L67)

| Position | Argument           | Type    | Description |
| -------- | ------------------ | ------- | ----------- |
| 1        | objectArg1         | object  | -           |
| -        | objectArg1.enabled | boolean | -           |

##### /plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#156 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#L156)

| Position | Argument           | Type      | Description |
| -------- | ------------------ | --------- | ----------- |
| 1        | objectArg1         | object    | -           |
| -        | objectArg1.enabled | undefined | -           |

##### /plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#193 [:link:](https://github.com/discourse/discourse/blob/main/plugins/discourse-ai/assets/javascripts/discourse/components/ai-full-page-search.gjs#L193)

| Position | Argument           | Type    | Description |
| -------- | ------------------ | ------- | ----------- |
| 1        | objectArg1         | object  | -           |
| -        | objectArg1.enabled | boolean | -           |

</details>

#### click-tracked [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/click-track.js#L98)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | href     | variable | True           | -           |

#### desktop-notification-opened [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/desktop-notifications.js#L179)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | objectArg1     | object   | True           | -           |
| -        | objectArg1.url | property | True           | -           |

#### keyboard-visibility-change [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/components/d-virtual-height.gjs#L59)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | keyboardVisible | variable | True           | -           |

#### push-notification-opened [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/push-notifications.js#L77)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | objectArg1     | object   | True           | -           |
| -        | objectArg1.url | property | True           | -           |

#### REFRESH_USER_SIDEBAR_CATEGORIES_SECTION_COUNTS_APP_EVENT_NAME [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/plugin-api.gjs#L2172)

No arguments passed to this event.

#### this.flagCreatedEvent [:link:](https://github.com/discourse/discourse/blob/main/frontend/discourse/app/lib/flag-targets/flag.js#L15)

| Position | Argument                       | Type     | Always Present | Description |
| -------- | ------------------------------ | -------- | -------------- | ----------- |
| 1        | flagModal.args.model.flagModel | property | True           | -           |
| 2        | postAction                     | variable | True           | -           |
| 3        | opts                           | variable | True           | -           |
