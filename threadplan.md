* Add last_opened_at/last_viewed_at to UserChatChannelMembership
* Update this every time we open the channel and set the last read
  message id
* When we get channel unreads, also get an unread_threads_count
  where the last_viewed_at for the channel < the last thread
  message created_at
* When the user opens the channel, change fetchMessages to only
  GET a /api/channels/:id endpoint that gets the channel info,
  first 20 messages needed, and the thread id array tracking state,
  as well as the threads + tracking for the OMs in that list of messages
* Every time we load messages for a channel we also get threads + tracking
  for the OMs
* When a new message is sent in a thread:
    * Get all users tracking that thread and send a messageBus event
      to the UI containing the thread object and tracking state WHERE
      the last sent message for the thread was created at > X days ago,
      so we can build the state from there in the UI.
    * Also update the sidebar channel blue dot in this case.
    * Determine whether we are tracking that thread in the overview
      array of IDs, and if so do nothing, if not add it to the ID
* When a thread is marked as read, remove its ID from the overview
  array of IDs

