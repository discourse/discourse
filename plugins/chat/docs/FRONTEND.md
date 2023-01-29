## Modules

<dl>
<dt><a href="#module_Collection">Collection</a></dt>
<dd></dd>
<dt><a href="#module_ChatApi">ChatApi</a></dt>
<dd></dd>
</dl>

<a name="module_Collection"></a>

## Collection

* [Collection](#module_Collection)
    * [module.exports](#exp_module_Collection--module.exports) ⏏
        * [new module.exports(resourceURL, handler)](#new_module_Collection--module.exports_new)
        * [.load()](#module_Collection--module.exports+load) ⇒ <code>Promise</code>
        * [.loadMore()](#module_Collection--module.exports+loadMore) ⇒ <code>Promise</code>


* * *

<a name="exp_module_Collection--module.exports"></a>

### module.exports ⏏
Handles a paginated API response.

**Kind**: Exported class  

* * *

<a name="new_module_Collection--module.exports_new"></a>

#### new module.exports(resourceURL, handler)
Create a Collection instance


| Param | Type | Description |
| --- | --- | --- |
| resourceURL | <code>string</code> | the API endpoint to call |
| handler | <code>callback</code> | anonymous function used to handle the response |


* * *

<a name="module_Collection--module.exports+load"></a>

#### module.exports.load() ⇒ <code>Promise</code>
Loads first batch of results

**Kind**: instance method of [<code>module.exports</code>](#exp_module_Collection--module.exports)  

* * *

<a name="module_Collection--module.exports+loadMore"></a>

#### module.exports.loadMore() ⇒ <code>Promise</code>
Attempts to load more results

**Kind**: instance method of [<code>module.exports</code>](#exp_module_Collection--module.exports)  

* * *

<a name="module_ChatApi"></a>

## ChatApi

* [ChatApi](#module_ChatApi)
    * [module.exports](#exp_module_ChatApi--module.exports) ⏏
        * [.channel(channelId)](#module_ChatApi--module.exports+channel) ⇒ <code>Promise</code>
        * [.channels()](#module_ChatApi--module.exports+channels) ⇒ [<code>module.exports</code>](#exp_module_Collection--module.exports)
        * [.moveChannelMessages(channelId, data)](#module_ChatApi--module.exports+moveChannelMessages) ⇒ <code>Promise</code>
        * [.destroyChannel(channelId, channelName)](#module_ChatApi--module.exports+destroyChannel) ⇒ <code>Promise</code>
        * [.createChannel(data)](#module_ChatApi--module.exports+createChannel) ⇒ <code>Promise</code>
        * [.categoryPermissions(categoryId)](#module_ChatApi--module.exports+categoryPermissions) ⇒ <code>Promise</code>
        * [.sendMessage(channelId, data)](#module_ChatApi--module.exports+sendMessage) ⇒ <code>Promise</code>
        * [.createChannelArchive(channelId, data)](#module_ChatApi--module.exports+createChannelArchive) ⇒ <code>Promise</code>
        * [.updateChannel(channelId, data)](#module_ChatApi--module.exports+updateChannel) ⇒ <code>Promise</code>
        * [.updateChannelStatus(channelId, status)](#module_ChatApi--module.exports+updateChannelStatus) ⇒ <code>Promise</code>
        * [.listChannelMemberships(channelId)](#module_ChatApi--module.exports+listChannelMemberships) ⇒ [<code>module.exports</code>](#exp_module_Collection--module.exports)
        * [.listCurrentUserChannels()](#module_ChatApi--module.exports+listCurrentUserChannels) ⇒ <code>Promise</code>
        * [.followChannel(channelId)](#module_ChatApi--module.exports+followChannel) ⇒ <code>Promise</code>
        * [.unfollowChannel(channelId)](#module_ChatApi--module.exports+unfollowChannel) ⇒ <code>Promise</code>
        * [.updateCurrentUserChannelNotificationsSettings(channelId, data)](#module_ChatApi--module.exports+updateCurrentUserChannelNotificationsSettings) ⇒ <code>Promise</code>


* * *

<a name="exp_module_ChatApi--module.exports"></a>

### module.exports ⏏
Chat API service. Provides methods to interact with the chat API.

**Kind**: Exported class  
**Implements**: <code>{@ember/service}</code>  

* * *

<a name="module_ChatApi--module.exports+channel"></a>

#### module.exports.channel(channelId) ⇒ <code>Promise</code>
Get a channel by its ID.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |

**Example**  
```js
this.chatApi.channel(1).then(channel => { ... })
```

* * *

<a name="module_ChatApi--module.exports+channels"></a>

#### module.exports.channels() ⇒ [<code>module.exports</code>](#exp_module_Collection--module.exports)
List all accessible category channels of the current user.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  
**Example**  
```js
this.chatApi.channels.then(channels => { ... })
```

* * *

<a name="module_ChatApi--module.exports+moveChannelMessages"></a>

#### module.exports.moveChannelMessages(channelId, data) ⇒ <code>Promise</code>
Moves messages from one channel to another.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the original channel. |
| data | <code>object</code> | Params of the move. |
| data.message_ids | <code>Array.&lt;number&gt;</code> | IDs of the moved messages. |
| data.destination_channel_id | <code>number</code> | ID of the channel where the messages are moved to. |

**Example**  
```js
this.chatApi
    .moveChannelMessages(1, {
      message_ids: [2, 3],
      destination_channel_id: 4,
    }).then(() => { ... })
```

* * *

<a name="module_ChatApi--module.exports+destroyChannel"></a>

#### module.exports.destroyChannel(channelId, channelName) ⇒ <code>Promise</code>
Destroys a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| channelName | <code>string</code> | The name of the channel to be destroyed, used as confirmation. |

**Example**  
```js
this.chatApi.destroyChannel(1, "foo").then(() => { ... })
```

* * *

<a name="module_ChatApi--module.exports+createChannel"></a>

#### module.exports.createChannel(data) ⇒ <code>Promise</code>
Creates a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| data | <code>object</code> | Params of the channel. |
| data.name | <code>string</code> | The name of the channel. |
| data.chatable_id | <code>string</code> | The category of the channel. |
| data.description | <code>string</code> | The description of the channel. |
| [data.auto_join_users] | <code>boolean</code> | Should users join this channel automatically. |

**Example**  
```js
this.chatApi
     .createChannel({ name: "foo", chatable_id: 1, description "bar" })
     .then((channel) => { ... })
```

* * *

<a name="module_ChatApi--module.exports+categoryPermissions"></a>

#### module.exports.categoryPermissions(categoryId) ⇒ <code>Promise</code>
Lists chat permissions for a category.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| categoryId | <code>number</code> | ID of the category. |


* * *

<a name="module_ChatApi--module.exports+sendMessage"></a>

#### module.exports.sendMessage(channelId, data) ⇒ <code>Promise</code>
Sends a message.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | ID of the channel. |
| data | <code>object</code> | Params of the message. |
| data.message | <code>string</code> | The raw content of the message in markdown. |
| data.cooked | <code>string</code> | The cooked content of the message. |
| [data.in_reply_to_id] | <code>number</code> | The ID of the replied-to message. |
| [data.staged_id] | <code>number</code> | The staged ID of the message before it was persisted. |
| [data.upload_ids] | <code>Array.&lt;number&gt;</code> | Array of upload ids linked to the message. |


* * *

<a name="module_ChatApi--module.exports+createChannelArchive"></a>

#### module.exports.createChannelArchive(channelId, data) ⇒ <code>Promise</code>
Creates a channel archive.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | Params of the archive. |
| data.selection | <code>string</code> | "new_topic" or "existing_topic". |
| [data.title] | <code>string</code> | Title of the topic when creating a new topic. |
| [data.category_id] | <code>string</code> | ID of the category used when creating a new topic. |
| [data.tags] | <code>Array.&lt;string&gt;</code> | tags used when creating a new topic. |
| [data.topic_id] | <code>string</code> | ID of the topic when using an existing topic. |


* * *

<a name="module_ChatApi--module.exports+updateChannel"></a>

#### module.exports.updateChannel(channelId, data) ⇒ <code>Promise</code>
Updates a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | Params of the archive. |
| [data.description] | <code>string</code> | Description of the channel. |
| [data.name] | <code>string</code> | Name of the channel. |


* * *

<a name="module_ChatApi--module.exports+updateChannelStatus"></a>

#### module.exports.updateChannelStatus(channelId, status) ⇒ <code>Promise</code>
Updates the status of a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| status | <code>string</code> | The new status, can be "open" or "closed". |


* * *

<a name="module_ChatApi--module.exports+listChannelMemberships"></a>

#### module.exports.listChannelMemberships(channelId) ⇒ [<code>module.exports</code>](#exp_module_Collection--module.exports)
Lists members of a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |


* * *

<a name="module_ChatApi--module.exports+listCurrentUserChannels"></a>

#### module.exports.listCurrentUserChannels() ⇒ <code>Promise</code>
Lists public and direct message channels of the current user.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

* * *

<a name="module_ChatApi--module.exports+followChannel"></a>

#### module.exports.followChannel(channelId) ⇒ <code>Promise</code>
Makes current user follow a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |


* * *

<a name="module_ChatApi--module.exports+unfollowChannel"></a>

#### module.exports.unfollowChannel(channelId) ⇒ <code>Promise</code>
Makes current user unfollow a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |


* * *

<a name="module_ChatApi--module.exports+updateCurrentUserChannelNotificationsSettings"></a>

#### module.exports.updateCurrentUserChannelNotificationsSettings(channelId, data) ⇒ <code>Promise</code>
Update notifications settings of current user for a channel.

**Kind**: instance method of [<code>module.exports</code>](#exp_module_ChatApi--module.exports)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | The settings to modify. |
| [data.muted] | <code>boolean</code> | Mutes the channel. |
| [data.desktop_notification_level] | <code>string</code> | Notifications level on desktop: never, mention or always. |
| [data.mobile_notification_level] | <code>string</code> | Notifications level on mobile: never, mention or always. |


* * *

