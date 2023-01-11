## Classes

<dl>
<dt><a href="#Collection">Collection</a></dt>
<dd></dd>
<dt><a href="#ChatApi">ChatApi</a></dt>
<dd></dd>
</dl>

## Functions

<dl>
<dt><a href="#load">load()</a> ⇒ <code>Promise</code></dt>
<dd><p>Loads first batch of results</p>
</dd>
<dt><a href="#loadMore">loadMore()</a> ⇒ <code>Promise</code></dt>
<dd><p>Attempts to load more results</p>
</dd>
<dt><a href="#channel">channel(channelId)</a> ⇒ <code>Promise</code></dt>
<dd><p>Get a channel by its ID.</p>
</dd>
<dt><a href="#channels">channels()</a> ⇒ <code>module:Collection</code></dt>
<dd><p>List all accessible category channels of the current user.</p>
</dd>
<dt><a href="#moveChannelMessages">moveChannelMessages(channelId, data)</a> ⇒ <code>Promise</code></dt>
<dd><p>Moves messages from one channel to another.</p>
</dd>
<dt><a href="#destroyChannel">destroyChannel(channelId, channelName)</a> ⇒ <code>Promise</code></dt>
<dd><p>Destroys a channel.</p>
</dd>
<dt><a href="#createChannel">createChannel(data)</a> ⇒ <code>Promise</code></dt>
<dd><p>Creates a channel.</p>
</dd>
<dt><a href="#categoryPermissions">categoryPermissions(categoryId)</a> ⇒ <code>Promise</code></dt>
<dd><p>Lists chat permissions for a category.</p>
</dd>
<dt><a href="#sendMessage">sendMessage(channelId, data)</a> ⇒ <code>Promise</code></dt>
<dd><p>Sends a message.</p>
</dd>
<dt><a href="#createChannelArchive">createChannelArchive(channelId, data)</a> ⇒ <code>Promise</code></dt>
<dd><p>Creates a channel archive.</p>
</dd>
<dt><a href="#updateChannel">updateChannel(channelId, data)</a> ⇒ <code>Promise</code></dt>
<dd><p>Updates a channel.</p>
</dd>
<dt><a href="#updateChannelStatus">updateChannelStatus(channelId, status)</a> ⇒ <code>Promise</code></dt>
<dd><p>Updates the status of a channel.</p>
</dd>
<dt><a href="#listChannelMemberships">listChannelMemberships(channelId)</a> ⇒ <code>module:Collection</code></dt>
<dd><p>Lists members of a channel.</p>
</dd>
<dt><a href="#listCurrentUserChannels">listCurrentUserChannels()</a> ⇒ <code>Promise</code></dt>
<dd><p>Lists public and direct message channels of the current user.</p>
</dd>
<dt><a href="#followChannel">followChannel(channelId)</a> ⇒ <code>Promise</code></dt>
<dd><p>Makes current user follow a channel.</p>
</dd>
<dt><a href="#unfollowChannel">unfollowChannel(channelId)</a> ⇒ <code>Promise</code></dt>
<dd><p>Makes current user unfollow a channel.</p>
</dd>
<dt><a href="#updateCurrentUserChannelNotificationsSettings">updateCurrentUserChannelNotificationsSettings(channelId, data)</a> ⇒ <code>Promise</code></dt>
<dd><p>Update notifications settings of current user for a channel.</p>
</dd>
</dl>

<a name="Collection"></a>

## Collection
**Kind**: global class  

* * *

<a name="new_Collection_new"></a>

### new Collection()
Handles a paginated API response.


* * *

<a name="ChatApi"></a>

## ChatApi
**Kind**: global class  
**Implements**: <code>Service</code>  

* * *

<a name="new_ChatApi_new"></a>

### new ChatApi()
Chat API service. Provides methods to interact with the chat API.


* * *

<a name="load"></a>

## load() ⇒ <code>Promise</code>
Loads first batch of results

**Kind**: global function  

* * *

<a name="loadMore"></a>

## loadMore() ⇒ <code>Promise</code>
Attempts to load more results

**Kind**: global function  

* * *

<a name="channel"></a>

## channel(channelId) ⇒ <code>Promise</code>
Get a channel by its ID.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |

**Example**  
```js
this.chatApi.channel(1).then(channel => { ... })
```

* * *

<a name="channels"></a>

## channels() ⇒ <code>module:Collection</code>
List all accessible category channels of the current user.

**Kind**: global function  
**Example**  
```js
this.chatApi.channels.then(channels => { ... })
```

* * *

<a name="moveChannelMessages"></a>

## moveChannelMessages(channelId, data) ⇒ <code>Promise</code>
Moves messages from one channel to another.

**Kind**: global function  

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

<a name="destroyChannel"></a>

## destroyChannel(channelId, channelName) ⇒ <code>Promise</code>
Destroys a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| channelName | <code>string</code> | The name of the channel to be destroyed, used as confirmation. |

**Example**  
```js
this.chatApi.destroyChannel(1, "foo").then(() => { ... })
```

* * *

<a name="createChannel"></a>

## createChannel(data) ⇒ <code>Promise</code>
Creates a channel.

**Kind**: global function  

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

<a name="categoryPermissions"></a>

## categoryPermissions(categoryId) ⇒ <code>Promise</code>
Lists chat permissions for a category.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| categoryId | <code>number</code> | ID of the category. |


* * *

<a name="sendMessage"></a>

## sendMessage(channelId, data) ⇒ <code>Promise</code>
Sends a message.

**Kind**: global function  

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

<a name="createChannelArchive"></a>

## createChannelArchive(channelId, data) ⇒ <code>Promise</code>
Creates a channel archive.

**Kind**: global function  

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

<a name="updateChannel"></a>

## updateChannel(channelId, data) ⇒ <code>Promise</code>
Updates a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | Params of the archive. |
| [data.description] | <code>string</code> | Description of the channel. |
| [data.name] | <code>string</code> | Name of the channel. |


* * *

<a name="updateChannelStatus"></a>

## updateChannelStatus(channelId, status) ⇒ <code>Promise</code>
Updates the status of a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| status | <code>string</code> | The new status, can be "open" or "closed". |


* * *

<a name="listChannelMemberships"></a>

## listChannelMemberships(channelId) ⇒ <code>module:Collection</code>
Lists members of a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |


* * *

<a name="listCurrentUserChannels"></a>

## listCurrentUserChannels() ⇒ <code>Promise</code>
Lists public and direct message channels of the current user.

**Kind**: global function  

* * *

<a name="followChannel"></a>

## followChannel(channelId) ⇒ <code>Promise</code>
Makes current user follow a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |


* * *

<a name="unfollowChannel"></a>

## unfollowChannel(channelId) ⇒ <code>Promise</code>
Makes current user unfollow a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |


* * *

<a name="updateCurrentUserChannelNotificationsSettings"></a>

## updateCurrentUserChannelNotificationsSettings(channelId, data) ⇒ <code>Promise</code>
Update notifications settings of current user for a channel.

**Kind**: global function  

| Param | Type | Description |
| --- | --- | --- |
| channelId | <code>number</code> | The ID of the channel. |
| data | <code>object</code> | The settings to modify. |
| [data.muted] | <code>boolean</code> | Mutes the channel. |
| [data.desktop_notification_level] | <code>string</code> | Notifications level on desktop: never, mention or always. |
| [data.mobile_notification_level] | <code>string</code> | Notifications level on mobile: never, mention or always. |


* * *

