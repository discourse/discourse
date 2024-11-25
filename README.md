# Discourse Developer Docs - Source Repository

> [!TIP]
> This repository is for creating/editing documentation. If you just want to browse the existing docs, head over to https://meta.discourse.org/c/documentation/10

This repository contains the the source files for Discourse's developer documentation. The `main` branch of the repository is automatically published in Discourse at https://meta.discourse.org/c/documentation/10

## Overview

This repository contains a script (`./sync_docs`) which takes the markdown files under `docs/` and uses the Discourse API to mirror them to a Discourse category.

The same script can be used to provide a live preview of docs in your own non-production Discourse environment.

## Directory Structure

Each doc is represented by a markdown file under `docs/**/*.md`. Directory/file names are only visible in the git repository, and are not synchronised to Discourse.

When synchronizing, directories/files are sorted lexographically, so we can use two-digit numbers to define the order in which sections/topics will appear in the Discourse sidebar.

`assets/` contains images which can be referenced by the docs.

## Sections

Each section directory must have an `index.md` file which defines the section title in the YAML frontmatter. For example

```md
---
title: My Section Title
---
```

Other content in the file is ignored.

## Doc Files

Each doc markdown file must define frontmatter with three keys:

- `title`: Used as the Discourse topic title
- `short_title`: Displayed in the sidebar
- `id`: A unique ID for the document. This is used to create a Discourse 'external_id' to associate a topic with the markdown file. 

  Changing this ID will cause the associated topic to be deleted and recreated. Avoid unless absolutely necessary.

The doc content should be included below the frontmatter. It can include any markdown/bbcode supported by Discourse.

Example:

```markdown
---
title: How to Develop themes for Discourse
short_title: Develop themes
id: theme-dev
---

How to develop themes:

1. Read the docs
2. Profit
```

## Images

Images (e.g. screenshots) for docs can be stored in the `/assets` directory. To reference them from the markdown, use the standard markdown image syntax, with a path like `/assets/my-image.png`. For example:

```
![some alt text](/assets/my-image.png)
```

The sync tool will automatically upload the images to Discourse, and replace the path with a discourse-specific `upload://` path. A mapping of repo-path to discourse-path will be persisted in an HTML comment at the end of the doc's topic.

Avoid hotlinking images from other sources. If you do, Discourse may download them and update the topic content. This will cause the docs sync tool to detect a diff, and update the topic unnecessarily.

## Contributing

When working on substantial changes, you may like to set up a staging environment to preview your changes.

1. Prepare a Discourse instance (could be a local development environment, or a production site)

   1. Create a category for the docs
   2. Install [discourse-doc-categories](https://github.com/discourse/discourse-doc-categories), and configure fully by adding the category & assigning an index topic
   3. Enable [DiscoTOC](https://meta.discourse.org/t/111143) for the category
   4. Ensure data-explorer is installed and enabled

2. Obtain an API key. This should be 'global' key, associated with an admin user account

3. Create a data explorer query with this content:
    ```sql
    -- [params]
    -- int :category_id = 1

    WITH index_topic_id AS (
      SELECT value::int as index_topic_id
      FROM category_custom_fields
      WHERE category_id = :category_id
      AND name='doc_category_index_topic'
    )
    SELECT
        t.id as t_id,
        p.id as first_p_id,
        t.external_id as external_id,
        title,
        raw,
        t.deleted_at,
        CASE WHEN index_topic_id=t.id THEN true ELSE false END as is_index_topic
    FROM topics t
    JOIN posts p on p.post_number = 1 AND p.topic_id = t.id
    JOIN index_topic_id ON true
    JOIN categories c ON c.id = t.category_id
    WHERE category_id = :category_id
    AND index_topic_id IS NOT NULL -- Prevents this query being used for non-doc categories
    AND (c.topic_id = index_topic_id OR c.topic_id != t.id) -- Skip category description topic, unless its also the index
    ```
    and note the query's id number from the URL in your browser

4. Run the script in 'watch' mode:

   ```bash
   bundle install

   DOCS_CATEGORY_ID=123 \
     DOCS_DATA_EXPLORER_QUERY_ID=123 \
     DOCS_TARGET="https://forum.example.com" \
     DOCS_API_KEY=abc \
     bundle exec ./sync_docs --watch
   ```
    For debugging, the script accepts a `-v` flag.

5. Once the script has completed the first run, all the topics should be visible in Discourse. Any edits to markdown files will be synced instantaneously to Discourse.
