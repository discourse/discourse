
To get started, copy the config.ex.yml to config.yml, and then update the properties for your Socialcast instance.

This importer uses the [Socialcast API](https://socialcast.github.io/socialcast/apidoc.html).

```
domain: 'my-socialcast-domain'
username: 'my-socialcast-username'
password: 'my-socialcast-password'
```

Create the directory for the json files to export: `mkdir output`
Then run `bundle exec ruby export.rb /path/to/config.yml`

If desired, edit the `socialcast_message.rb` file to set the category
and tags for each topic based on the name of the Socialcast group it was
originally posted to.

You must create categories with the same names first in your site.

All topics will get the `DEFAULT_TAG` at minimum.

Topics posted to a group that matches any group name in the `TAGS_AND_CATEGORIES`
map will get the associated category and tags.

Other topics will be tagged with the original groupname and placed in the
`DEFAULT_CATEGORY`.

To run the import, run `bundle exec ruby import.rb`

To run the import in a production, run `RAILS_ENV=production bundle exec ruby import.rb`
