# Importing from VBulletin 5

This is a set of scripts whose goal is migrating from VBulletin 5 to Discourse. These were originally
written in 2016. They were recently updated to migrate a VBulletin 5.7.5 system to Discourse
2026.3.0. More details are below in the "Origin Story" section. There are a few files here:

* `vbulletin5.rb`: Both the full-forum importer as well as a library of functions used in
  specialized scripts.
* `import_vb5_avatars.rb`: A script that imports avatars from VBulletin.
* `import_vb5_pm.rb`: A script to import private messages (PMs) from VBulletin as Discourse messages
* `redo_vb5_post.rb`: A script that will re-import a single VBulletin post into Discourse
* `import_vb5_selection.rb`: A script like `redo_vb5_post.rb`, but it takes a list of VBulletin node
  IDs and imports them. More efficient than either `vbulletin5.rb` (which imports *everything*) or
  running a loop of `redo_vb5_post.rb` which initializes everything and imports one post.

## Idealized Journey

The detailed migration instructions are in [MIGRATION.md](MIGRATION.md). Here's a high-level summary.

1. Install Discourse
2. Install MariaDB in your Discourse container and add support for MySQL to rails
3. Copy over all your avatars and attachments (unless these are stored in your MySQL database)
4. Run `vbulletin5.rb`. Binge watch a few shows, learn a new language, write a great novel. Do
   something to pass the time.
5. Run `import_vb5_pm.rb` to import PMs. Go get a good meal while you wait.
6. Run `import_vb5_avatars.rb` to bring in avatars.
7. Spot check. Fix anything that imported badly.
8. Do post-migration configuration of Discourse
9. Open your Discourse to business

## Note

This code is **slow**. It emphasizes correctness and thoroughness at the cost of speed. When
migrating a forum with 20K users and 1.6M nodes and 100K PMs it took about 38-40 *hours*. It does a
decent job of remembering progress, so it can be interrupted and restarted.

# VBulletin 5 Support

This script now handles some VBulletin 5 features.

## Polls

This script tries to recreate VBulletin polls as Discourse polls. If it can find Discourse users
that correspond to VBulletin voters, it will import their votes so they show up in Discourse.
Deleted users are treated as anonymous voters.

**One weird edge case**: VBulletin allowed options in a poll to be literally identical. Moreoveer,
in my forum I had a poll with two different options whose text was identical (it was a mistake), and
they had *different* vote totals. Discourse will not allow that. The import script will discard one
of them and all its corresponding votes.

## Table support

Apparently in VB4, there was support for BBCode tables like this:

```
[TABLE]
  [TR]
    [TD]Item[/TD][TD]Quantity[/TD][TD]Price[/TD]
  [/TR]
  [TR][TD]Clown shoes[/TD][TD]1[/TD][TD]$32.22[/TD][/TR]
[/TABLE]
```

It seems that in VB5 they removed that support. In my VBulletin 5 system, though, the `rawtext`
still had the BBCode table codes, even though VB5 was not rendering them. This importer converts
them directly to basic HTML. The original BBCode allowed for attributes inside the tags like `[TD
WIDTH=200]`, this strips everything out to just basic `<td>` tags.

```html
<TABLE>
<TR><TD>Item</TD><TD>Quantity</TD><TD>Price</TD></TR>
<TR><TD>Clown shoes</TD><TD>1</TD><TD>$32.22</TD></TR>
</TABLE>
```

**Note**: VBulletin table code resulted in a lot of lines with leading spaces. Markdown considers
leading spaces to be a code block, so HTML is not interpreted. It would be displayed as code in the
post. The table handling code strips leading spaces when it converts BBCode tables. My VBulletin had
nothing to do with programming, so there were zero posts that had any kind of inline code. This
approach might be too crude and need to be adjusted or removed for a more technical forum.

## Processing BBCode

### Dropping unsupported tags

There seem to have been a bunch of BBCode tags that were supported in the past, but have no analog in
Discourse like `[LEFT]` and `[RIGHT]`. The code strips all of these.

### Supported BBCode tags

There are some BBCode tags where [the BBCode plugin](https://github.com/discourse/discourse-bbcode)
might handle them just fine. Despite that, this code tends to strip them out. You can modify the
code not to strip them. These include `[COLOR]`, `[SIZE]`, and `[FONT]`. Why strip them if they
could be handled? See the next point.

### BBCode converted to HTML

Some BBCode is converted its equivalent HTML. Tags like `[B]` become `<strong>` and so on. This is
required because of HTML tables. Neither markdown nor BBCode will be parsed if it appears inside an
HTML table cell. So this code chooses to convert most BBCode to HTML throughout, even though
markdown and BBCode would work in a lot of non-table situations.

## Processing VBulletin Smilies

There are a couple different kinds of smilies:
* Image-based smilies. I had code like: `[img]/forum/images/smilies/smile.gif[/img]`
* Code-based smilies. Code in posts like `:smile:` or `:thumb:`.

Both of these get converted to Emoji characters like 😊 or 👍. The support for smilies is based on what I
found in my VBulletin. You might have some that I don't have, or you might not have these at all.

## Attachments

The code recognizes several different syntaxes for attachments. If you have an old forum that has VB3 and VB4 posts in it, you might have any number of these.

* `[ATTACH]7876[/ATTACH]`
* `[ATTACH=JSON]{"data-align":"none","data-attachmentid":"2897123","data-size":"full"}[/ATTACH]`
* `[IMG]/vb5/filedata/fetch?id=2914424[/IMG]`
* `[URL=filedata/fetch?filedataid=64298]`

The code tries to detect all of these, parse them, and then convert them to a Discourse-compatible upload
and a markdown reference.

## HTML Entity Handling

It is possible to specify a character in HTML entity notation that, when it is decoded, becomes an
invalid byte sequence in UTF-8. For example: `&#xD810;`. This is syntactically valid HTML, but the
value `0xD810` is an illegal Unicode scalar value. HTML decoding in Ruby would throw an exception on
these during processing. There is no obvious way (or reason) to keep these. So invalid HTML entities
are dropped. Other HTML entities are preserved. (These are probably the result of ISO 8859-1
encoding from many years ago, which is not the same as UTF-8 encoding of Unicode)

You might also have zero-width Unicode characters in your posts. If so, there's a
`fix_zero_width_spaces.rb` script that will find them and remove them. That's optional.

## VBulletin Post Types

VBulletin defines a few different types of posts in the `node` table. The original `vbulletin5.rb`
only supported a few of them. This code now supports:

* Forum
* Channel
* Text
* Gallery
* Link
* Video
* Poll
* Comments

The Gallery and Link types are really not that special. They are just normal posts that pull in
pictures or create links. They're not *exactly* like text posts, though. So the code fetches the
various bits from the right tables and turns them into text posts in Discourse.

### Comments

In vBulletin 5, a comment is a reply to a post that isn't the topic starter. They visually
thread under the post they're replying to. Discourse doesn't have this concept. Everything is a
post. So when VBulletin comments come along, we convert them to regular posts. In order to visually
distinguish them from regular posts, we insert a markdown header that says `> In reply to [UserA's
post](/p/post-name-etc)`

## Importing Users

There are a couple subtleties with importing users.

### Duplicate emails

VBulletin can allow an email address to register more than one account. That doesn't work with
Discourse. This code has a clumsy, but deterministic approach. There's a better approach that is
sketched here but not implemented.

During the import, the first time we the email address `person@example.com`, we import the user
normally. The second time we encounter `person@example.com` that email address has already been
assigned to a user in Discourse. The code generates a deterministic, but invalid email address. For
example: `vb-user-2951@fake.invalid` if it's VBulletin ID 2951. There will always be exactly one
discourse user with `person@example.com`, and some number of users with invalid email addresses.

A smarter way to do it would be to use plus addressing. E.g., `person+2951@example.com`. This might
work, but it's not certain. Not all email systems support this approach. It would allow a person to
receive email and even login, but only if their email system supports it.

### Group Memberships

There is a `usergroupid` column in the VBulletin `user` table that represents the primary group for
the user. The `membergroupids` column will contain a comma separated list of IDs for the `group`
table. E.g., `21,22,31,33`. So this script now handles figuring out the memberships and inserting
users into all the groups.

# Operational Changes

The scripts operate a little differently than before. Originally, there was just one script
`vbulletin5.rb` that did all the work in one pass.

## Library Mode

Now `vbulletin5.rb` is sort of a library. This allows standalone scripts to leverage its code. It
can (and should) still be called on its own. But it can also be leveraged by other scripts.

Most importantly, it allows `redo_vb5_post.rb` to re-import a single post. I used this **a lot**
while developing. And then, after I discovered something big that hadn't been imported right, I
would get a long list of nodeids. And then I run `import_vb5_selection.rb` on them to re-import
them.

# Origin Story

This extra work on vbulletin5 importing was all created to help move
[CareCure](https://www.carecure.net/) from VBulletin 5.7.5 to Discourse. CareCure is very old,
having been a variety of different things since the late 1990s. It finally became a VBulletin forum
around 2002. In the spinal cord injury (SCI) and traumatic brain injury (TBI) world, it is a pretty
unique resource. Maintaining historical posts is important. It's also a community of people who,
sadly, have a life expectancy that is distinctly shorter than average. So keeping memorial posts and
memories online is really valuable to that community. I needed to migrate with high fidelity. Even
trivial posts like "what kind of coffee do you drink" were important for me to preserve and bring
forward.

The site started on VBulletin 3, was upgraded to VBulletin 4, and eventually, when I took over in
2019, I migrated it to VBulletin 5. I kept upgrading until we got to VBulletin 5.7.5. Prior to me,
different admins owned and operated it. Some with more skill than others. I can't complain: my
predecessor built the version I inherited by typing with a mouth stick. Talk about sysadmin on hard
mode! But it means that, over the life of the system, files got moved from path-to-path, sometimes
orphaning or losing attachment files. Choices were made and unmade, like storing attachments in the
database or not. The database was **messy**. The URL of the site changed over the years from
`sci.rutgers.edu` to `www.carecure.org` to `www.carecure.net`. So internal URLs were wrong a lot.
Plus, in the 24 years of its existence, the internet went from HTTP to HTTPS, making a lot of URLs
wrong. I did a lot of bulk edits in the MariaDB over the years, trying to update links so they work.

This means that error handling and opinionated choices in this update to `vbulletin5.rb` are meant
to be general purpose, but sometimes I prioritized situations that affected me, and I did not have
the ability to test situations I didn't have (like images stored in the database).

## Stats from CareCure at the time of migration

These are from April 2026.

| Asset           |    Count |
| --------------- |  ------: |
| Users           |    20907 |
| Custom Avatars  |     8999 |
| Text Posts      |  1791950 |
| Private Messages|   150059 |
| Attachments     |    10834 |
| Comments        |     5325 |
| Photo Posts     |     4357 |
| Redirect Posts  |     3221 |
| Polls           |     1593 |
| Gallery Posts   |     1076 |
| Link Posts      |      110 |
