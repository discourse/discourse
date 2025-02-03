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

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1365 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1365)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

##### /app/assets/javascripts/discourse/app/lib/topic-bookmark-manager.js#57 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/topic-bookmark-manager.js#L57)

| Position | Argument                      | Type            | Description |
| -------- | ----------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData     | property        | -           |
| 2        | this.bookmarkModel.attachedTo | called_function | -           |

##### /app/assets/javascripts/discourse/app/models/post.js#588 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post.js#L588)

| Position | Argument            | Type     | Description |
| -------- | ------------------- | -------- | ----------- |
| 1        | data                | variable | -           |
| 2        | objectArg2          | object   | -           |
| -        | objectArg2.target   | string   | -           |
| -        | objectArg2.targetId | property | -           |

##### /app/assets/javascripts/discourse/app/models/post.js#609 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post.js#L609)

| Position | Argument            | Type     | Description |
| -------- | ------------------- | -------- | ----------- |
| 1        | null                | null     | -           |
| 2        | objectArg2          | object   | -           |
| -        | objectArg2.target   | string   | -           |
| -        | objectArg2.targetId | property | -           |

##### /app/assets/javascripts/discourse/app/models/topic.js#695 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/topic.js#L695)

| Position | Argument            | Type            | Description |
| -------- | ------------------- | --------------- | ----------- |
| 1        | null                | null            | -           |
| 2        | bookmark.attachedTo | called_function | -           |

##### /plugins/chat/assets/javascripts/discourse/lib/chat-message-interactor.js#346 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/lib/chat-message-interactor.js#L346)

| Position | Argument                  | Type            | Description |
| -------- | ------------------------- | --------------- | ----------- |
| 1        | bookmarkFormData.saveData | property        | -           |
| 2        | bookmark.attachedTo       | called_function | -           |

</details>


### card
#### card:close [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/components/chat/direct-message-button.gjs#L32)

No arguments passed to this event.

#### card:hide [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/card-contents-base.js#L264)

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

##### /plugins/chat/assets/javascripts/discourse/services/chat.js#452 [:link:](https://github.com/discourse/discourse/blob/main/plugins/chat/assets/javascripts/discourse/services/chat.js#L452)

| Position | Argument                               | Type     | Description |
| -------- | -------------------------------------- | -------- | ----------- |
| 1        | this.chatStateManager.isDrawerExpanded | property | -           |

</details>


### composer
#### composer:cancel-upload [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L646)

No arguments passed to this event.

#### composer:cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1605)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/services/composer.js#1605 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1605)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/services/composer.js#1613 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1613)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/services/composer.js#1626 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1626)

No arguments passed to this event.

</details>

#### composer:created-post [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1183)

No arguments passed to this event.

#### composer:div-resizing [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L88)

No arguments passed to this event.

#### composer:edited-post [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1171)

No arguments passed to this event.

#### composer:find-similar [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L69)

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

#### composer:open [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1391)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.model | property | True           | -           |

#### composer:opened [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L175)

No arguments passed to this event.

#### composer:reply-reloaded [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L969)

| Position | Argument | Type | Always Present | Description |
| -------- | -------- | ---- | -------------- | ----------- |
| 1        | this     | this | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/models/composer.js#969 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L969)

| Position | Argument | Type | Description |
| -------- | -------- | ---- | ----------- |
| 1        | this     | this | -           |

##### /app/assets/javascripts/discourse/app/models/composer.js#988 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L988)

| Position | Argument | Type | Description |
| -------- | -------- | ---- | ----------- |
| 1        | this     | this | -           |

</details>

#### composer:resize-ended [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L148)

No arguments passed to this event.

#### composer:resize-started [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L143)

No arguments passed to this event.

#### composer:resized [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-body.js#L125)

No arguments passed to this event.

#### composer:saved [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1152)

No arguments passed to this event.

#### composer:toolbar-popup-menu-button-clicked [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L675)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | menuItem | variable | True           | -           |

#### composer:typed-reply [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1262)

No arguments passed to this event.

#### this.composerEventPrefix:all-uploads-complete [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L381)

No arguments passed to this event.

#### this.composerEventPrefix:apply-surround [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L769)

| Position | Argument                | Type    | Always Present | Description |
| -------- | ----------------------- | ------- | -------------- | ----------- |
| 1        | [grid]                  | string  | True           | -           |
| 2        | [/grid]                 | string  | True           | -           |
| 3        | grid_surround           | string  | True           | -           |
| 4        | objectArg4              | object  | True           | -           |
| -        | objectArg4.useBlockMode | boolean | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#769 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L769)

| Position | Argument                | Type    | Description |
| -------- | ----------------------- | ------- | ----------- |
| 1        | [grid]                  | string  | -           |
| 2        | [/grid]                 | string  | -           |
| 3        | grid_surround           | string  | -           |
| 4        | objectArg4              | object  | -           |
| -        | objectArg4.useBlockMode | boolean | -           |

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#684 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L684)

| Position | Argument                | Type    | Description |
| -------- | ----------------------- | ------- | ----------- |
| 1        | [grid]                  | string  | -           |
| 2        | [/grid]                 | string  | -           |
| 3        | grid_surround           | string  | -           |
| 4        | objectArg4              | object  | -           |
| -        | objectArg4.useBlockMode | boolean | -           |

</details>

#### this.composerEventPrefix:closed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L808)

No arguments passed to this event.

#### this.composerEventPrefix:replace-text [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L610)

| Position | Argument                  | Type     | Always Present | Description |
| -------- | ------------------------- | -------- | -------------- | ----------- |
| 1        | matchingPlaceholder.index | property | True           | -           |
| 2        | replacement               | variable | True           | -           |
| 3        | objectArg3                | object   | False          | -           |
| -        | objectArg3.regex          | variable | False          | -           |
| -        | objectArg3.index          | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#610 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L610)

| Position | Argument                  | Type     | Description |
| -------- | ------------------------- | -------- | ----------- |
| 1        | matchingPlaceholder.index | property | -           |
| 2        | replacement               | variable | -           |
| 3        | objectArg3                | object   | -           |
| -        | objectArg3.regex          | variable | -           |
| -        | objectArg3.index          | variable | -           |

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#654 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L654)

| Position | Argument    | Type     | Description |
| -------- | ----------- | -------- | ----------- |
| 1        | match       | variable | -           |
| 2        | replacement | variable | -           |

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#741 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L741)

| Position | Argument                  | Type     | Description |
| -------- | ------------------------- | -------- | ----------- |
| 1        | matchingPlaceholder.index | property | -           |
| 2        | string                    | string   | -           |
| 3        | objectArg3                | object   | -           |
| -        | objectArg3.regex          | variable | -           |
| -        | objectArg3.index          | variable | -           |

</details>

#### this.composerEventPrefix:upload-cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L284)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file.id  | property | True           | -           |

#### this.composerEventPrefix:upload-error [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L423)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | file     | variable | True           | -           |

#### this.composerEventPrefix:upload-started [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L339)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | file.name | property | True           | -           |

#### this.composerEventPrefix:upload-success [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L374)

| Position | Argument  | Type     | Always Present | Description |
| -------- | --------- | -------- | -------------- | ----------- |
| 1        | file.name | property | True           | -           |
| 2        | upload    | variable | True           | -           |

#### this.composerEventPrefix:uploads-aborted [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L130)

No arguments passed to this event.

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#130 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L130)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#177 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L177)

No arguments passed to this event.

</details>

#### this.composerEventPrefix:uploads-cancelled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L402)

No arguments passed to this event.

#### this.composerEventPrefix:uploads-preprocessing-complete [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/uppy/composer-upload.js#L498)

No arguments passed to this event.

#### this.composerEventPrefix:will-close [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L804)

No arguments passed to this event.

#### this.composerEventPrefix:will-open [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L194)

No arguments passed to this event.


### composer-messages
#### composer-messages:close [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L905)

No arguments passed to this event.

#### composer-messages:create [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L767)

| Position | Argument                | Type            | Always Present | Description |
| -------- | ----------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1              | object          | True           | -           |
| -        | objectArg1.extraClass   | string          | True           | -           |
| -        | objectArg1.templateName | string          | True           | -           |
| -        | objectArg1.body         | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/services/composer.js#767 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L767)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#777 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L777)

| Position | Argument                | Type            | Description |
| -------- | ----------------------- | --------------- | ----------- |
| 1        | objectArg1              | object          | -           |
| -        | objectArg1.extraClass   | string          | -           |
| -        | objectArg1.templateName | string          | -           |
| -        | objectArg1.body         | called_function | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#956 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L956)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#980 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L980)

| Position | Argument                | Type     | Description |
| -------- | ----------------------- | -------- | ----------- |
| 1        | objectArg1              | object   | -           |
| -        | objectArg1.extraClass   | string   | -           |
| -        | objectArg1.templateName | string   | -           |
| -        | objectArg1.body         | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#989 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L989)

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
#### d-editor:preview-click-group-card [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-editor.js#L166)

| Position | Argument     | Type     | Always Present | Description |
| -------- | ------------ | -------- | -------------- | ----------- |
| 1        | event.target | property | True           | -           |
| 2        | event        | variable | True           | -           |

#### d-editor:preview-click-user-card [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-editor.js#L158)

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


### do-not-disturb
#### do-not-disturb:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/user.js#L1253)

| Position | Argument                  | Type     | Always Present | Description |
| -------- | ------------------------- | -------- | -------------- | ----------- |
| 1        | this.do_not_disturb_until | property | True           | -           |


### dom
#### dom:clean [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/clean-dom-on-route-change.js#L32)

No arguments passed to this event.


### draft
#### draft:destroyed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1536)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | key      | variable | True           | -           |


### emoji-picker
#### emoji-picker:close [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L900)

No arguments passed to this event.


### full-page-search
#### full-page-search:trigger-search [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/full-page-search.js#L567)

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
#### header:hide-topic [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic.js#L395)

No arguments passed to this event.

#### header:keyboard-trigger [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L449)

| Position | Argument         | Type     | Always Present | Description |
| -------- | ---------------- | -------- | -------------- | ----------- |
| 1        | objectArg1       | object   | True           | -           |
| -        | objectArg1.type  | string   | True           | -           |
| -        | objectArg1.event | variable | False          | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#449 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L449)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#520 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L520)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#529 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L529)

| Position | Argument         | Type     | Description |
| -------- | ---------------- | -------- | ----------- |
| 1        | objectArg1       | object   | -           |
| -        | objectArg1.type  | string   | -           |
| -        | objectArg1.event | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#536 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L536)

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

#### header:update-topic [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1739)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | composer.topic | property | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1739 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1739)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | topic    | variable | -           |

##### /app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#163 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#L163)

| Position | Argument | Type    | Description |
| -------- | -------- | ------- | ----------- |
| 1        | null     | null    | -           |
| 2        | 5000     | integer | -           |

##### /app/assets/javascripts/discourse/app/routes/topic.js#420 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic.js#L420)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | model    | variable | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1176 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1176)

| Position | Argument       | Type     | Description |
| -------- | -------------- | -------- | ----------- |
| 1        | composer.topic | property | -           |

</details>


### inserted-custom-html
#### inserted-custom-html:this.name [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/custom-html.js#L33)

No arguments passed to this event.


### keyboard
#### keyboard:move-selection [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L793)

| Position | Argument                   | Type     | Always Present | Description |
| -------- | -------------------------- | -------- | -------------- | ----------- |
| 1        | objectArg1                 | object   | True           | -           |
| -        | objectArg1.articles        | variable | True           | -           |
| -        | objectArg1.selectedArticle | variable | True           | -           |


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

#### page:like-toggled [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/widgets/post.js#L1156)

| Position | Argument   | Type     | Always Present | Description |
| -------- | ---------- | -------- | -------------- | ----------- |
| 1        | post       | variable | True           | -           |
| 2        | likeAction | variable | True           | -           |

#### page:topic-loaded [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/routes/topic-from-params.js#L93)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | topic    | variable | True           | -           |


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
#### post:created [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1233)

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

##### /app/assets/javascripts/discourse/app/services/composer.js#1184 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1184)

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

#### post-stream:posted [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1245)

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

##### /app/assets/javascripts/discourse/app/controllers/topic.js#901 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L901)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | variable | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1406 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1406)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1723 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1723)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | args     | variable | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1873 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1873)

| Position | Argument      | Type            | Description |
| -------- | ------------- | --------------- | ----------- |
| 1        | objectArg1    | object          | -           |
| -        | objectArg1.id | called_function | -           |

##### /app/assets/javascripts/discourse/app/lib/flag-targets/flag.js#26 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/flag-targets/flag.js#L26)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#623 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L623)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/post-bookmark-manager.js#60 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/post-bookmark-manager.js#L60)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/models/composer.js#1098 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1098)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/models/composer.js#1110 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1110)

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

##### /app/assets/javascripts/discourse/app/models/post.js#592 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/post.js#L592)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | objectArg1    | object   | -           |
| -        | objectArg1.id | property | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1165 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1165)

No arguments passed to this event.

##### /app/assets/javascripts/discourse/app/services/composer.js#1172 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1172)

| Position | Argument      | Type            | Description |
| -------- | ------------- | --------------- | ----------- |
| 1        | objectArg1    | object          | -           |
| -        | objectArg1.id | called_function | -           |

##### /app/assets/javascripts/discourse/app/services/composer.js#1179 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/services/composer.js#L1179)

No arguments passed to this event.

</details>


### quote-button
#### quote-button:edit [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L351)

No arguments passed to this event.

#### quote-button:quote [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L335)

No arguments passed to this event.


### sidebar-hamburger-dropdown
#### sidebar-hamburger-dropdown:rendered [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/sidebar/hamburger-dropdown.gjs#L26)

No arguments passed to this event.


### site-header
#### site-header:force-refresh [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/narrow-desktop.js#L26)

No arguments passed to this event.


### this.eventPrefix
#### this.eventPrefix:insert-text [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#L429)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | markdown | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#429 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#L429)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | table    | variable | -           |

##### /app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#483 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/textarea-text-manipulation.js#L483)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | markdown | variable | -           |

</details>


### topic
#### topic:created [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/composer.js#L1235)

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

#### topic:jump-to-post [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L952)

| Position | Argument | Type            | Always Present | Description |
| -------- | -------- | --------------- | -------------- | ----------- |
| 1        | this.get | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/controllers/topic.js#952 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L952)

| Position | Argument | Type            | Description |
| -------- | -------- | --------------- | ----------- |
| 1        | this.get | called_function | -           |

##### /app/assets/javascripts/discourse/app/controllers/topic.js#1333 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/controllers/topic.js#L1333)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | postId   | variable | -           |

</details>

#### topic:keyboard-trigger [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/keyboard-shortcuts.js#L516)

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
#### topic-entrance:show [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/basic-topic-list.js#L109)

| Position | Argument            | Type            | Always Present | Description |
| -------- | ------------------- | --------------- | -------------- | ----------- |
| 1        | objectArg1          | object          | True           | -           |
| -        | objectArg1.topic    | variable        | True           | -           |
| -        | objectArg1.position | called_function | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/basic-topic-list.js#109 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/basic-topic-list.js#L109)

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

##### /app/assets/javascripts/discourse/app/components/topic-list-item.js#35 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/topic-list-item.js#L35)

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
#### user-drafts:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/user.js#L1259)

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
#### user-reviewable-count:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/models/user.js#L1264)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | count    | variable | True           | -           |


### user-status
#### user-status:changed [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/instance-initializers/subscribe-user-notifications.js#L227)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | data     | variable | True           | -           |


### user-stream
#### user-stream:new-item-inserted [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-stream.gjs#L138)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | element1 | variable | True           | -           |


### other events
#### click-tracked [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/click-track.js#L98)

| Position | Argument | Type     | Always Present | Description |
| -------- | -------- | -------- | -------------- | ----------- |
| 1        | href     | variable | True           | -           |

#### decorate-non-stream-cooked-element [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L511)

| Position | Argument      | Type     | Always Present | Description |
| -------- | ------------- | -------- | -------------- | ----------- |
| 1        | cookedElement | variable | True           | -           |

<details><summary>Detailed List</summary>

##### /app/assets/javascripts/discourse/app/components/composer-editor.js#511 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/composer-editor.js#L511)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | preview  | variable | -           |

##### /app/assets/javascripts/discourse/app/components/d-editor.js#260 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-editor.js#L260)

| Position | Argument      | Type     | Description |
| -------- | ------------- | -------- | ----------- |
| 1        | cookedElement | variable | -           |

##### /app/assets/javascripts/discourse/app/components/discourse-banner.gjs#47 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/discourse-banner.gjs#L47)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | element1 | variable | -           |

##### /app/assets/javascripts/discourse/app/components/user-stream.gjs#44 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-stream.gjs#L44)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | element1 | variable | -           |

##### /app/assets/javascripts/discourse/app/components/user-stream.gjs#139 [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/user-stream.gjs#L139)

| Position | Argument | Type     | Description |
| -------- | -------- | -------- | ----------- |
| 1        | element1 | variable | -           |

</details>

#### desktop-notification-opened [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/desktop-notifications.js#L179)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | objectArg1     | object   | True           | -           |
| -        | objectArg1.url | property | True           | -           |

#### keyboard-visibility-change [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/components/d-virtual-height.gjs#L59)

| Position | Argument        | Type     | Always Present | Description |
| -------- | --------------- | -------- | -------------- | ----------- |
| 1        | keyboardVisible | variable | True           | -           |

#### push-notification-opened [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/push-notifications.js#L77)

| Position | Argument       | Type     | Always Present | Description |
| -------- | -------------- | -------- | -------------- | ----------- |
| 1        | objectArg1     | object   | True           | -           |
| -        | objectArg1.url | property | True           | -           |

#### REFRESH_USER_SIDEBAR_CATEGORIES_SECTION_COUNTS_APP_EVENT_NAME [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs#L2358)

No arguments passed to this event.

#### this.flagCreatedEvent [:link:](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/flag-targets/flag.js#L15)

| Position | Argument                       | Type     | Always Present | Description |
| -------- | ------------------------------ | -------- | -------------- | ----------- |
| 1        | flagModal.args.model.flagModel | property | True           | -           |
| 2        | postAction                     | variable | True           | -           |
| 3        | opts                           | variable | True           | -           |
