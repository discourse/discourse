# Discourse Events

Adds the ability to create a dynamic calendar in the first post of a topic.

Topic discussing the plugin itself can be found here: [https://meta.discourse.org/t/discourse-calendar/97376](https://meta.discourse.org/t/discourse-calendar/97376)

## Event registration forms

Admins manage reusable forms under **Admin → Plugins → Events → Registration forms**. Members in **Groups that can create events** can also create forms and manage their own. In the event editor, **Create new** opens the form editor in a new tab. Saving the form selects it in the event draft. Published events keep the questions selected at publication.

RSVP-enabled events default to **Do not track registration**. Selecting **Username/Email only** records a signed-in member’s details automatically when they RSVP as Going. Selecting a custom form opens it for the member to complete.

**Admin → Plugins → Events → Submissions** shows registration counts and the latest submission time by event. The first submission starts a personal message to the event hosts with the member’s answers, username, and submission time. Later submissions appear as replies. Hosts can export a CSV from the event menu. Account email addresses are included only in exports requested by an administrator who also hosts the event.

Signed-in members see their primary account email as a read-only field when they register. Form previews show the viewer’s own address.

## Customization

### Events

- `discourse_post_event_event_will_start` this DiscourseEvent will be triggered one hour before an event starts
- `discourse_post_event_event_started` this DiscourseEvent will be triggered when an event starts
- `discourse_post_event_event_ended` this DiscourseEvent will be triggered when an event ends

### Custom Fields

Custom fields can be set in plugin settings. Once added a new form will appear on event UI.
These custom fields are available when a plugin event is triggered.

### Holidays

See an incorrect or missing holiday? Familiarize yourself with the [holiday definition Syntax](vendor/holidays/definitions/doc/SYNTAX.md). Then make your updates in the `vendor/holiday/definitions` directory.

Generate updated holidays as follows.

```sh
cd vendor/holidays

# Generate holiday definitions
rake generate:definitions
```

Install the plugin and switch to the discourse root(not the plugin directory).

```sh
# Collect all holiday regions into assets/javascripts/lib/regions.js
bin/rails javascript:update_constants
```

### Interactions with Other Plugins

You can use an element of this plugin with the [Right Sidebar Blocks](https://github.com/discourse/discourse-right-sidebar-blocks) component. You'll want to ensure the desired route is enabled via the `events calendar categories` setting. In Right Sidebar Block's settings, the block name will be `upcoming-events-list`, and the params use this [syntax](https://momentjs.com/docs/#/displaying/format/), for example `MMMM D, YYYY`.
