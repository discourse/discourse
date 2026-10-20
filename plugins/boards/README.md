# Boards Plugin

A Discourse plugin that provides configurable Boards with:

- Global board definitions
- Board-level read/write ACLs via groups
- Optional topic-backed cards
- Optional lightweight floater cards
- Hybrid card membership (`auto`, `manual_in`, `manual_out`)

Boards source topics from `base_filter_query`, enforce topic visibility via guardian-secured queries, and persist card placement/order at the board level.
