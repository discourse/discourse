# Concord

Bundled from [discourse/discourse-concord-theme at e093108](https://github.com/discourse/discourse-concord-theme/tree/e09310840738790308f07042da988c45ea350936).

A theme that turns Discourse into a chat server, where everything is a channel.

It replaces the sidebar with one section where everything is a channel:

- **Categories** are forum channels: every category the user can see
- **Chat channels** are text channels: every open one the user can see, joined
  or not, as in Discord. Opening one joins it, so leaving a channel doesn't
  take it out of the list (mute it instead). Chat's directory is loaded on
  each page load, up to 500 channels.
- **Voice rooms** (voice plugin) are voice channels; clicking one joins it,
  and who's in each one is listed under it, as the voice plugin's own sidebar
  does
- **Tags** can be tag channels, with the `include_tags` setting (off by
  default for now)

Channels can be sorted into collapsible sections, kept in the
`sidebar_sections` setting. Anything not in a section is listed at the top
with no heading, all kinds together, alphabetically. Each section
heading has its own `+`, which opens the
modal with that section picked; admins can also pick the section in the modal.
Sections are saved through the admin theme-setting endpoint, so only admins can
change them, and others see changes on their next page load. (The setting used
to be `sidebar_groups`; a settings migration carries it over.)

The `+` next to the site name at the top opens a create-channel modal. It offers the
channel types the user is allowed to create, and a private toggle that limits
the channel to selected groups:

- Forum: a category whose permissions are set to the groups
- Text: a chat channel. Chat takes its access from a category, so each one
  gets its own backing category under the `chat_container_category` category
  (created if missing, and hidden from the list). Its members are auto-joined.
  Posting in a chat channel only needs Reply on its category, so that's all a
  backing category grants (and the container only See): nobody but admins can
  start topics there, and its "About" topic is closed.
  Deleting the channel from its menu deletes that category too, so chat's own
  delete button is hidden on those channels' settings pages.
- Voice: a private room with the groups' current members added (up to 200).
  Later group members don't get access, since rooms have no group access.

Subcategories have no channel of their own, since the category dropdown that
would lead to them is hidden. Instead a forum channel with subcategories always
lists them above its topics, as boxes, whatever its own settings say.

The default panels (forum, chat) are both redirected to this one, so moving
between topics and chat doesn't swap the sidebar out. The admin and user
panels are left alone.

Not yet covered: a friends list, or a chat home page beyond the DM list
below. A chat home page is coming to core.

## Menus

Every channel row has a `…` button on hover, and every section heading has one
next to its `+`. Items depend on the channel's kind and what the user may do:

- Forum: mark as read, notifications (all posts / default / mute), rename and
  delete for category editors
- Text: mark as read, notifications (all messages / only mentions / nothing),
  mute, rename and delete for staff
- Voice: rename and delete for the room's managers
- Privacy, for whoever can edit the channel: the create modal's private
  switch and groups, filled in from the channel. A forum changes its
  category's permissions (groups keep the access level they had), a text
  channel made from the create modal changes its backing category, and a text
  channel on a regular category links to that category's security settings
  instead, since a forum channel shares it. A voice room becomes public or
  private, and can add groups' current members. Since core requires a
  subcategory's groups to see its parent, a forum keeps the groups its
  subcategories use and can't go private while one is public.
- DMs: mark as read, notifications (all messages / only mentions / nothing),
  mute, and close conversation
- All: copy link, and for admins, move to section (including a new one,
  named on the spot)
- Section headings (admins): rename, move up, move down, delete

A channel's menu leads with mark as read, rename, privacy and copy link, then
notifications and move to section (a submenu of the sections, so it doesn't
lengthen the menu), with delete on its own at the end.

Core hides the row button on narrow touch screens, so there a long press on a
channel opens its menu instead.

## Layout

Core's header contents are hidden at every width, and a channel header row
takes their place inside the same header: the server name over the channel
list, then the current channel's icon, name, description, actions and a search
button that opens core's search panel as a dropdown. Living inside core's
header keeps every height calculation built on it (chat, composer, sticky
elements) working. Chat always opens full page, never in the drawer, through
chat's own preference for it (set again before each navigation, since chat's
`-` shortcut switches it to the drawer). Chat's own channel bar is hidden; its threads, pins and
settings are in the row. A forum channel's settings (core's wrench) are there
too, for people who can edit the category. In a topic, the row's icon is a
back arrow to its forum channel, the title links to the top of the topic, and
the category under it links to the category. In a text channel the search
button opens chat's own message search for that channel instead of site search.
On phones it goes to core's full page search instead of the dropdown, as core's
own header does. Core's `/` (search) and `p` (user menu) shortcuts open the
row's search and the user panel's notifications, since core's own menus would
open in the hidden header; `/` still goes to the welcome banner's search when
that's on screen.

Left of the row's buttons is core's `before-header-panel` outlet, the one core
renders left of its own header icons, so what's made for core's header shows
up here. Core's language switcher, one of those hidden header icons, is shown
there too, under core's own conditions (content localization on, and
`content_localization_language_switcher` set for the viewer).

In admin the row keeps to admin: the AI, DM and create buttons beside the server
name, the member list and search are left out, and an X at the end goes back
to the last page outside admin (or home), as core's "Back to Forum" does.

Below the `md` breakpoint (phones, and narrow desktop windows) the row starts
with a hamburger button that opens the channel list as core's slide-in panel,
with the server name and user panel in it. The button asks core's header to
toggle the panel, so its animation, scroll lock and close-on-tap-outside are
core's own, and the server name stays at the top of it as the channels
scroll. A channel's threads, pins and settings fold into a `…` menu there,
ahead of the row's other buttons (a lone action stays a button). The row ends
with the user's avatar (with its unread badge), which opens core's user menu
as a slide-in from the right, as core's mobile header does; the user panel at
the foot of the channel list is then only for signing in.

The foot of the sidebar shows the current user; clicking opens the user
menu's profile tab on its own (status, presence, summary, activity,
preferences, log out). The bell beside it, carrying the unread badge, opens
core's user menu (notifications, messages, bookmarks) without that tab.
Signed-out visitors get log in and sign up buttons there. Core's sidebar
footer is hidden.

The main column fills the window beside the channel list. Topics are the
exception: the posts stay at core's reading width, with the timeline beside
them, and are centred in the space. The composer (when its preview is hidden)
starts where the topic does.

## Server menu

The site name at the top of the channel list (or the site's logo, at the
name's height, when one is set; `show_logo` turns that off) opens a menu of the site-wide
pages core's header and sidebar used to link to: home (`home_link` turns it
off), invite, admin, review (with
its pending count), about, FAQ or guidelines, groups, users, badges, and
keyboard shortcuts. For people who review, the site name carries the review
queue's count. The links are core's own community section links, so who
sees each one follows core's rules. Those pages (and each group and badge)
get their title in the header row, and the badges pages' own headings and the
group page's name are hidden so it isn't said twice.

## Direct messages

DMs are kept out of the server's channel list, in a Home view. A button
beside the server name (with the DMs' unread count) swaps the channel list for
the user's DMs: a "Back to all channels" link and a button to start a
new one at the top, laid out like Discourse AI's conversations, then every DM
and group chat they follow, with avatars and unread counts. Core's "Back to
Forum" link, atop the admin and AI sidebars, reads "Back to all channels" too. Opening a DM
switches to the list on its own, and going to any of the server's channels
switches back.

## AI conversations

With Discourse AI, people who can start an AI bot conversation get a button
before the DM one, standing in for Discourse AI's header button. Like the DM
button it's a toggle that swaps the channel list for Discourse AI's own list of
conversations, without leaving the page; pressing it again, or the list's
"Back to all channels", puts the channels back. Discourse AI's pages still
open with its list showing. The `ai_conversations_link` setting turns it off.

## Coming back

The site reopens the channel someone was last in (a topic counts
as its category's channel) when they come back to the site's address. Links to
any other page go where they say, the home link still goes home, and a channel
that's gone or private falls back to the homepage. It's per user and per
browser, for signed-in people only; `remember_last_channel` turns it off.

## Member list

A panel down the right of the page for signed-in people, toggled by the
people icon in the header row (the choice is remembered per browser). Below the
`md` breakpoint the same icon slides it in from the right over the page
instead; it starts closed and closes on navigation or a tap beside it. Voice
channels have none, since who's in the call is listed under the channel. It
shows:

- online members of each group in `member_list_roles` (admins and moderators
  by default), a section per role
- everyone else online, then offline

On a private chat channel it covers the channel's members; on a public one,
and elsewhere, everyone on the site. "Online" means active anywhere on the site in the last few
minutes (chat would only count people while chat is open, so the theme has it
count the whole site), plus the who's-online plugin when installed. Hiding
your presence still hides you. Members load 50
at a time as you scroll; a chat channel's first 250 load up front so its online
members can be found. Names open user cards, as they do on the page.

## Tests

System specs (`spec/system`) drive the whole thing in a browser, against a
Discourse checkout with the chat and voice plugins:

    LOAD_PLUGINS=1 bin/rspec themes/concord/spec/system/concord_sidebar_spec.rb

Unit tests (`test/unit`) cover the logic on its own: sections, privacy
permissions, member list sorting, long press, link badges and the settings
migration. With the theme installed on a running development site:

    bin/qunit --theme-id -3 --qunit-path /theme-qunit --rails-env development
