# Try member onboarding side by side

Use this walkthrough to compare the administrator's configuration page with the
member's saved checklist on the same Lovelace-enabled community. See the
[product guide](lovelace.md) for installation, authorization, architecture, and
the full test suite.

## Set up two sessions

1. Use a test community with `lovelace_enabled` enabled. Saved configuration
   changes apply to every member of that community.
2. Open two separate browser profiles, or a normal window and a private window.
   Sign in as an administrator in one and an ordinary member in the other.
   Two tabs in the same browser profile share the signed-in account.
3. In the administrator's window, open
   `/admin/plugins/lovelace/member-onboarding`.
4. In the member's window, open `/latest`. Use an account that has not dismissed
   its checklist. Place the two windows alongside each other.

The admin page contains the editable checklist and item bank alongside each
other, with the actual member widget in a full-width temporary preview below.
Add or edit items in the modal form; category, topic, and chat destinations
provide resource selectors.
The member page shows the persistent checklist above the welcome banner. A fresh
configuration has three selected suggestions and notifications in the item bank;
an existing configuration keeps its saved items and order.

## Compare configuration and progress

1. As the member, mark one item complete using its circle button. Reload the
   member page: the completion count and checked item stay saved.
2. As the administrator, check an item in the preview. It changes only the
   preview's temporary count. Reload the member page: the member's progress
   stays unchanged.
3. As the administrator, edit a selected item's title and choose **Save item**.
   Wait for the saved row and confirmation toast. Reload the member page to see
   the new title. Progress on that item is retained.
4. Add **Set up your notifications** from the bank if it is available, or add a
   custom item. Reload the member page: the new item appears unchecked and the
   total increases. Existing completions stay checked.
5. Reload the admin page. Its preview returns to zero completed items while the
   configuration stays saved. Reloading the member page keeps member progress.

Configuration changes reach an already open member window on a full page reload.
The admin preview's links use the administrator's permissions and open in a new
tab. Follow links in the member window to check the member's actual access and
personal settings destinations. Following a link does not mark an item complete.

## Check the member experience

- Minimize, reload, and expand the checklist. Progress and the minimized state
  persist for that member.
- Before finishing, uncheck and recheck an item to try reversing completion.
  Complete the remaining items: the rows hide, confetti drops, and a brief
  congratulatory message appears. A thin green line matching the **Dismiss**
  button’s width drains directly beneath it during the three-second countdown,
  then the checklist fades away. Choose **Dismiss** to start the fade
  sooner. Reload: the checklist stays dismissed. Reduced-motion preferences skip
  confetti and fading and show a stepped countdown instead.
- Complete every item in the admin preview to try the same sequence without
  saving member progress. Choose **Reset preview** to replay it.
- Resize each window to a narrow width. The admin items and bank stack above the
  preview; member rows wrap and the checklist controls remain available.
- With another undismissed member, try **Dismiss checklist**. Dismissal persists
  after reload and later admin edits. Use another undismissed member account for
  a fresh pass; there is no member reset control.

If the widget is missing, check the enable setting, ensure the editable checklist
has at least one item, and use a signed-in member who has not dismissed it. The
separate `/lovelace/checklist` suggestion page and
`/admin/plugins/lovelace/checklist` selection tab do not configure this widget.

## Automated coverage

The comparison flow is covered by
`spec/system/compare_member_onboarding_spec.rb`. It uses independent admin and
member browser sessions to check saved edits, new items, retained member
completion, and temporary preview progress. It also opens a separate member
session after the admin page, then verifies adding a suggestion, reordering, and
creating an item still save and persist. Both flows keep CSRF protection enabled.
Run from the Discourse root:

```sh
LOAD_PLUGINS=1 RAILS_ENV=test bin/rspec plugins/lovelace/spec/system/compare_member_onboarding_spec.rb
```
