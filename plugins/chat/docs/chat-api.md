<a name="module_ChatApi"></a>

## ChatApi
**Access**: public  

* [ChatApi](#module_ChatApi)
    * [.channel(channelId)](#module_ChatApi+channel) ⇒ <code>Promise</code>
    * [.channels()](#module_ChatApi+channels) ⇒ <code>Collection</code>
    * [.moveChannelMessages(channelId, data)](#module_ChatApi+moveChannelMessages) ⇒ <code>Promise</code>
    * [.destroyChannel(channelId, channelName)](#module_ChatApi+destroyChannel) ⇒ <code>Promise</code>
    * [.createChannel(data)](#module_ChatApi+createChannel) ⇒ <code>Promise</code>
    * [.categoryPermissions(categoryId)](#module_ChatApi+categoryPermissions) ⇒ <code>Promise</code>
    * [.sendMessage(channelId, data)](#module_ChatApi+sendMessage) ⇒ <code>Promise</code>
    * [.createChannelArchive(channelId, data)](#module_ChatApi+createChannelArchive) ⇒ <code>Promise</code>
    * [.updateChannel(channelId, data)](#module_ChatApi+updateChannel) ⇒ <code>Promise</code>
    * [.updateChannelStatus(channelId, status)](#module_ChatApi+updateChannelStatus) ⇒ <code>Promise</code>
    * [.listChannelMemberships(channelId)](#module_ChatApi+listChannelMemberships) ⇒ <code>Collection</code>
    * [.listCurrentUserChannels()](#module_ChatApi+listCurrentUserChannels) ⇒ <code>Promise</code>
    * [.followChannel(channelId)](#module_ChatApi+followChannel) ⇒ <code>Promise</code>
    * [.unfollowChannel(channelId)](#module_ChatApi+unfollowChannel) ⇒ <code>Promise</code>
    * [.updateCurrentUserChannelNotificationsSettings(channelId, data)](#module_ChatApi+updateCurrentUserChannelNotificationsSettings) ⇒ <code>Promise</code>

<a name="module_ChatApi+channel"></a>

### chatApi.channel(channelId) ⇒ <code>Promise</code>
Get a channel by its ID.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |

**Example**  
```js
this.chatApi.channel(1).then(channel => { ... })
```
<a name="module_ChatApi+channels"></a>

### chatApi.channels() ⇒ <code>Collection</code>
List all accessible category channels of the current user.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  
**Example**  
```js
this.chatApi.channels.then(channels => { ... })
```
<a name="module_ChatApi+moveChannelMessages"></a>

### chatApi.moveChannelMessages(channelId, data) ⇒ <code>Promise</code>
Moves messages from one channel to another.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

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
<a name="module_ChatApi+destroyChannel"></a>

### chatApi.destroyChannel(channelId, channelName) ⇒ <code>Promise</code>
Destroys a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| channelName | <code>string</code> | The name of the channel to be destroyed, used as confirmation. |

**Example**  
```js
this.chatApi.destroyChannel(1, "foo").then(() => { ... })
```
<a name="module_ChatApi+createChannel"></a>

### chatApi.createChannel(data) ⇒ <code>Promise</code>
Creates a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

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
<a name="module_ChatApi+categoryPermissions"></a>

### chatApi.categoryPermissions(categoryId) ⇒ <code>Promise</code>
Lists chat permissions for a category.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| categoryId | <code>number</code> | ID of the category. |

<a name="module_ChatApi+sendMessage"></a>

### chatApi.sendMessage(channelId, data) ⇒ <code>Promise</code>
Sends a message.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | ID of the channel. |
| data | <code>object</code> | Params of the message. |
| data.message | <code>string</code> | The raw content of the message in markdown. |
| data.cooked | <code>string</code> | The cooked content of the message. |
| [data.in_reply_to_id] | <code>number</code> | The ID of the replied-to message. |
| [data.staged_id] | <code>number</code> | The staged ID of the message before it was persisted. |
| [data.upload_ids] | <code>Array.&lt;number&gt;</code> | Array of upload ids linked to the message. |

<a name="module_ChatApi+createChannelArchive"></a>

### chatApi.createChannelArchive(channelId, data) ⇒ <code>Promise</code>
Creates a channel archive.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | Params of the archive. |
| data.selection | <code>string</code> | "new_topic" or "existing_topic". |
| [data.title] | <code>string</code> | Title of the topic when creating a new topic. |
| [data.category_id] | <code>string</code> | ID of the category used when creating a new topic. |
| [data.tags] | <code>Array.&lt;string&gt;</code> | tags used when creating a new topic. |
| [data.topic_id] | <code>string</code> | ID of the topic when using an existing topic. |

<a name="module_ChatApi+updateChannel"></a>

### chatApi.updateChannel(channelId, data) ⇒ <code>Promise</code>
Updates a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | Params of the archive. |
| [data.description] | <code>string</code> | Description of the channel. |
| [data.name] | <code>string</code> | Name of the channel. |

<a name="module_ChatApi+updateChannelStatus"></a>

### chatApi.updateChannelStatus(channelId, status) ⇒ <code>Promise</code>
Updates the status of a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| status | <code>string</code> | The new status, can be "open" or "closed". |

<a name="module_ChatApi+listChannelMemberships"></a>

### chatApi.listChannelMemberships(channelId) ⇒ <code>Collection</code>
Lists members of a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |

<a name="module_ChatApi+listCurrentUserChannels"></a>

### chatApi.listCurrentUserChannels() ⇒ <code>Promise</code>
Lists channels of the current user.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  
<a name="module_ChatApi+followChannel"></a>

### chatApi.followChannel(channelId) ⇒ <code>Promise</code>
Makes current user follow a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |

<a name="module_ChatApi+unfollowChannel"></a>

### chatApi.unfollowChannel(channelId) ⇒ <code>Promise</code>
Makes current user unfollow a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |

<a name="module_ChatApi+updateCurrentUserChannelNotificationsSettings"></a>

### chatApi.updateCurrentUserChannelNotificationsSettings(channelId, data) ⇒ <code>Promise</code>
Update notifications settings of current user for a channel.

**Kind**: instance method of [<code>ChatApi</code>](#module_ChatApi)  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | The settings to modify. |
| [data.muted] | <code>boolean</code> | Mutes the channel. |
| [data.desktop_notification_level] | <code>string</code> | Notifications level on desktop: never, mention or always. |
| [data.mobile_notification_level] | <code>string</code> | Notifications level on mobile: never, mention or always. |

