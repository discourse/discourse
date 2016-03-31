
To get started, copy the config.ex.yml to config.yml, and then update the properties for your Quandora instance.

```
domain: 'my-quandora-domain'
username: 'my-quandora-username'
password: 'my-quandora-password'
```

Create the directory for the json files to export: `mkdir output`
Then run `ruby export.rb /path/to/config.yml`

To import, run `ruby import.rb`

To run tests, include id's for a KB and Question that includes answers and comments

```
kb_id: 'some-kb-id'
question_id: 'some-question-id'
```

