
To get started, copy the config.ex.yml to config.yml, and then update the properties for your Socialcast instance.

This importer uses the [Socialcast API](https://socialcast.github.io/socialcast/apidoc.html).

```
domain: 'my-socialcast-domain'
username: 'my-socialcast-username'
password: 'my-socialcast-password'
```

Create the directory for the json files to export: `mkdir output`
Then run `ruby export.rb /path/to/config.yml`

Create a category named "Socialcast Import" or all topics will be imported into
the "Uncategorized" category.

Topics will be tagged with the names of the groups they were originally posted
in on Socialcast.

To run the import, run `ruby import.rb`
