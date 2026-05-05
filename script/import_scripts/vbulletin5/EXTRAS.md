# Extra Migration Utilities

You might not need these, but they're here in case you do.

* `redo_vb5_post.rb`: A script that will re-import a single VBulletin post into Discourse
* `import_vb5_selection.rb`: A script like `redo_vb5_post.rb`, but it takes a list of VBulletin node IDs and imports them. More efficient than either `vbulletin5.rb` (which imports *everything*) or running a loop of `redo_vb5_post.rb` which re-initializes everything for each post.
* `fix_zero_width_spaces.rb`: A script that hunts for some unicode characters that are invisible, but possibly present in posts. I had a bunch of URLs that ended with zero-width spaces, so they were invalid. This finds and deletes them.
* `import_vb5_avatars.rb`: This is a standalone script for only importing avatars. The main `vbulletin5.rb` probably does this right, so you probably don't need to run this.
* `fix_vb5_comments.rb`: This is a standalone script that looks for posts that had vBulletin comments in them. It makes sure that all the comments and the posts are threaded in the right order. This is probably unnecessary for most people, since `vbulletin5.rb` probably gets it right.
