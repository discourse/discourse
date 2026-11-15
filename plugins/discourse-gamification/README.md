# **Discourse Gamification** Plugin

## Scoped API keys

To award points without granting a global API key, create a **Granular** API key
for a **Single user** who is an admin and select only
`gamification: create_score_events`. Send the key in the `Api-Key` header when
calling `POST /admin/plugins/gamification/score_events.json` with `user_id`, `date`,
`points`, and optionally `description` and `category_id`.

The score events API provides independent scopes:

- `gamification: read_score_events`: `GET /admin/plugins/gamification/score_events.json`
- `gamification: create_score_events`: `POST /admin/plugins/gamification/score_events.json`
- `gamification: update_score_events`: `PUT /admin/plugins/gamification/score_events.json`

These scopes do not grant access to other admin operations or bypass the admin-user
requirement. The create scope allows both awarding and deducting points, so treat
its key as a sensitive credential.

## Category-scoped leaderboards

A leaderboard with its own nonempty **Scorable categories** list counts only
category-based activity: topics, replies, likes, reactions, and accepted solutions.
Visits, reading totals, invitations, flags, and chat activity are excluded because
these scoring sources do not filter by category. Score overrides do not enable these
sources on a category-scoped leaderboard.

Manual score adjustments count on a category-scoped leaderboard only when they are
assigned to one of its categories, through `category_id` on the score events API or
the **Category** field of the workflows "Award score" action. Leaderboards without
their own category list count uncategorized adjustments, plus categorized ones that
match the site-wide `scorable_categories` setting when it is set.

Leaderboards without their own category list retain global scoring behavior. The
site-wide `scorable_categories` setting filters category-based actions while
retaining site-wide score sources.

After upgrading an existing category-scoped leaderboard, use **Recalculate scores**
in the gamification admin interface with a start date covering the leaderboard's
history. Refreshing positions alone does not remove previously calculated global
points; scheduled recalculations only update recent scores.

# User Card
<img width="585" alt="Screen Shot 2022-03-18 at 9 33 24 AM" src="https://user-images.githubusercontent.com/50783505/159036553-b162f5b7-5acd-4134-ba5f-fa8dbb7f8f8f.png">

# User Metadata
<img width="1129" alt="Screen Shot 2022-03-18 at 10 48 25 AM" src="https://user-images.githubusercontent.com/50783505/159036559-15eff295-47f6-4294-bc4d-8ea4452b6d60.png">

# Directory
<img width="1106" alt="Screen Shot 2022-03-18 at 10 48 54 AM" src="https://user-images.githubusercontent.com/50783505/159036563-d866a819-e9c4-4c92-a415-1d51f5fe6d1a.png">
