# Lovelace

Lovelace provides an administrator configuration page for a community’s member
onboarding checklist. Start with editable profile and guidelines suggestions, add
notification setup from the item bank, and restore removed suggestions with their
edits intact. Add custom items, reorder or remove items, and try the checklist in
an interactive member preview.

Members see a persistent checklist above the welcome banner, with saved progress,
minimize and dismiss controls, and a brief celebration when they finish. Completed
items hide immediately, and a thin, button-width green timer beneath **Dismiss**
shows when the celebration will dismiss. After three seconds it fades out gently;
**Dismiss** starts the fade sooner. The checklist stays dismissed on return visits and uses the editable
configuration.

It also provides a member checklist with ready-made suggestions. Administrators
choose which suggestions appear and can restore removed items from an item bank.
The editable preview and the member suggestion selection are saved separately.

Standard admin reports count checklist views, item link clicks, item completions,
full completion, and dismissals. Try the member widget at `/latest` while signed
in with an account that has not dismissed it, then compare its activity with the
onboarding reports. Aggregate statistics describe adoption, selected suggestions,
custom destination types, and member outcomes.

See the [product guide](doc/lovelace.md) for installation, behavior,
authorization, architecture, and tests.

To compare the admin and member experiences, follow the
[side-by-side onboarding walkthrough](doc/member-onboarding-walkthrough.md).

Explore the [earlier completion alternatives](doc/onboarding-completion-options.html)
in a standalone interactive comparison.

The [dismissal timer design reference](doc/onboarding-dismissal-timer-options.html)
retains the three alternatives. Option A is implemented in the member widget and
admin preview: a button-width line beneath **Dismiss**, without helper copy.
