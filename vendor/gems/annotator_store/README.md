Annotator Store
===============

[![Gem Version](https://badge.fury.io/rb/annotator_store.svg)][5]
[![Build Status](https://travis-ci.org/itsmrwave/annotator_store-gem.svg?branch=master)][13]

Rails engine to implement a [Ruby on Rails][18] backend store implementation for
[Annotator][annotator].

> Annotator an open-source JavaScript library to easily add annotation
> functionality to any webpage. Annotations can have comments, tags, links,
> users, and more. Annotator is designed for [easy extensibility][1] so its a
> cinch to add a new feature or behaviour. Annotator also fosters an active
> developer community with contributors from four continents, building 3rd party
> plugins allowing the annotation of PDFs, EPUBs, videos, images, sound, and
> more.

The gem should be up on [rubygems.org][5], the [CHANGELOG here][7] and [all the
releases listed here][8].


Contents
--------

1. Dependencies & Versions
2. Installation
3. Annotation Format
4. API Endpoints
5. Development
6. Testing & Appraisals
7. Versioning
8. Contributing
9. License


Dependencies & Versions
----------------------

This engine requires Rails `>= 4.0` and Ruby `>= 1.9.3` and supports more than
one database.

Supported Ruby versions:

* [X] 1.9.3
* [X] 2.0.0
* [X] 2.1.0
* [X] 2.1.1
* [X] 2.1.2

Supported Rails versions:

* [X] 4.0.x
* [X] 4.1.x
* [X] 4.2.x

Supported databases:

* [X] MySQL
* [X] PostgreSQL

_'Supported'_ means that the test suite is designed to cover these versions
only. If your version isn't supported [raise a ticket][19]; make sure you
include the versions.

Sometimes when the build is failing, it's probably a few of these
configurations. Have a [look at the builds here][13] and see section on testing
& appraisals for more information.


Installation
------------

Add this line to your application's Gemfile:

    gem 'annotator_store'

And then from the `APP_ROOT` execute:

    $ bundle install

Configure your database credentials in your `config/database.yml` file and then run the
migrations to create the tables to store the annotations.

    # Copy migrations over from the engine
    $ rake annotator_store:install:migrations

    # To run the copied migration
    $ rake db:migrate

Then mount it in `config/routes.rb`:

    # Configures store endpoint in your app
    mount AnnotatorStore::Engine, at: '/annotator_store'

Now it should be ready for use. All the endpoints will be available at
`http://0.0.0.0:3000/annotator_store` in your app.


Annotation Format
-----------------

An annotation is a JSON document that contains a number of fields describing the
position and content of an annotation within a specified document:

    {
      "id": 1,                                   # unique id (added by backend)
      "annotator_schema_version": "v1.0",        # schema version: default v1.0
      "created": "2011-05-24T18:52:08.036814",   # created datetime in iso8601 format (added by backend)
      "updated": "2011-05-26T12:17:05.012544",   # updated datetime in iso8601 format (added by backend)
      "text": "A note I wrote",                  # content of annotation
      "quote": "the text that was annotated",    # the annotated text (added by frontend)
      "uri": "http://example.com",               # URI of annotated document (added by frontend)
      "ranges": [                                # list of ranges covered by annotation (usually only one entry)
        {
          "start": "/p[69]/span/span",           # (relative) XPath to start element
          "end": "/p[70]/span/span",             # (relative) XPath to end element
          "startOffset": 0,                      # character offset within start element
          "endOffset": 120                       # character offset within end element
        }
      ]
    }


API Endpoints
-------------

### Root

| Method | Path | Returns                                                                  |
| ------ | ---- | ------------------------------------------------------------------------ |
| GET    | /    | `200 OK` with an object containing store metadata, including API version |

Returns (example):

    $ curl http://example.com/annotator_store
    {
      "name": "Annotator Store API",
      "version": "2.0.0",
      "links": {
        "annotation": {
          "create": {
            "url": "http://example.com/annotator_store/annotations",
            "method": "POST",
            "description": "Create or add new annotations."
          },
          "read": {
            "url": "http://example.com/annotator_store/annotations/:id",
            "method": "GET",
            "description": "Read, retrieve or view existing annotation."
          },
          "update": {
            "url": "http://example.com/annotator_store/annotations/:id",
            "method": "PUT/PATCH",
            "description": "Update or edit existing annotation."
          },
          "delete": {
            "url": "http://example.com/annotator_store/annotations/:id",
            "method": "DELETE",
            "description": "Delete or deactivate existing annotation."
          }
      },
      "search": {
          "url": "http://example.com/annotator_store/search",
          "method": "GET",
          "description": "Search for annotations"
        }
      }
    }


### Create

| Method  | Path         | Returns                                                                    |
| ------- | ------------ | -------------------------------------------------------------------------- |
| POST    | /annotations | `201 CREATED` with location in header set to the appropriate read endpoint |

Receives an annotation object in the proper annotation format, sent with `Content-Type: application/json`.

Returns (example):

    $ curl http://example.com/annotator_store/annotations
    {
      "id": 1,
      "text": "Annotation text",
      ...
    }


### Read

| Method | Path             | Returns                            |
| ------ | ---------------- | ---------------------------------- |
| GET    | /annotations/:id | `200 OK` with an annotation object |

Returns (example):

    $ curl http://example.com/annotator_store/annotations/d41d8cd98f00b204e9800998ecf8427e
    {
      "id": 1,
      "text": "Annotation text",
      ...
    }


### Update

| Method     | Path             | Returns                                                               |
| ---------- | ---------------- | --------------------------------------------------------------------- |
| PUT/PATCH  | /annotations/:id | `200 OK` with location in header set to the appropriate read endpoint |

Receives attributes in the proper annotation format, sent with `Content-Type: application/json`.

Returns (example):

    $ curl http://example.com/annotator_store/annotations/d41d8cd98f00b204e9800998ecf8427e
    {
      "id": 1,
      "text": "Annotation text",
      ...
    }


### Delete

| Method     | Path             | Returns                                    |
| ---------- | ---------------- | ------------------------------------------ |
| DELETE     | /annotations/:id | `204 NO CONTENT` and obviously, no content |


### Search

| Method | Path     | Returns                                                 |
| ------ | -------- | ------------------------------------------------------- |
| GET    | /search  | An object with total and rows fields                    |

_Total_ is an integer denoting the total number of annotations matched by the
search, while _rows_ is a list containing what might be a subset of these
annotations.

If implemented, this endpoint should also support the `limit` and `offset` query
parameters for paging through results.

_Ps: Pagination with limit and offset not yet implemented. See [issue #1][15]._

Returns (example):

    $ curl http://example.com/annotator_store/search?text=annotation
    {
      "total": 43127,
      "rows": [
        {
          "id": 1,
          "text": "Updated annotation text",
          ...
        },
        ...
      ]
    }


Development
-----------

There's a dummy Rails application in the `spec/dummy` folder. This application
is used as a mounting point for the engine, to make testing the engine on a
Rails app extremely simple. This directory should be treated like a typical
Rails testing environment, allowing for unit, functional and integration tests.

The current dummy app was generated using Rails 4.1.6 and with PostgreSQL as the
default store. The app depends on the `DB` environment variable to know which
settings to use for the database. See `config/database.yml` for details.

Set the `DB` environment variable to either `mysql` or `postgres` to choose
between the two.

    # To use MySQL
    $ DB=mysql [commands to run]

    # To use PostgreSQL
    $ DB=postgres [commands to run]

You can start up the dummy app to give it a spin by running `rails server` in
`spec/dummy` and then browse to `http://0.0.0.0:3000/`. There's a README in
there with a few details on setup, make sure you check it out.


Testing & Appraisals
--------------------

You may extend the dummy application by generating controllers, models or views
from within the directory (`spec/dummy`), and then use those to test our engine
(I've done this already but feel free to add). Then use the rspec command to run
your specs.

  	#=> Run all specs
  	$ bundle exec rspec

  	#=> Run only model specs example ...
  	$ bundle exec rspec spec/models

  	#=> Run only specs for AnnotatorStore::AnnotationsController ...
  	$ bundle exec rspec spec/controllers/annotations_controller_spec.rb

These will run the tests as per your local default configuration.

The [appraisal gem][16] is used to integrate with bundler and rake to test the
engine against different versions of dependencies in repeatable scenarios called
_'appraisals'_. This makes it easy to check for regressions in the library
without interfering with day-to-day development using Bundler.

As a result, a separate test run is created for each Ruby version and every
Rails version (see `travis.yml` file for specifics).

Locally you can test for different Rails versions. For example:

  	# Run specs against rails 4.0.12
  	$ appraisal rails-4.0.12 rspec spec

  	# Run specs against rails 4.1.8
  	$ appraisal rails-4.1.8 rspec spec

  	# Run specs against rails 4.2.0
  	$ appraisal rails-4.2.0 rspec spec

Check the Appraisal file at the root for the different rails configurations.
[Learn more about appraisals here][17].

PostgreSQL is configured to be the default database configuration. Set the `DB`
environment variable to either `mysql` or `postgres` to choose between the two.

    # To use MySQL
    $ DB=mysql [commands to run your tests]

    # To use PostgreSQL
    $ DB=postgres [commands to run your tests]

Automated tests are configured and set up to [run on Travis-CI][13]. Any push or
pull request will be built. The `DB` environment variable should be set to
either `mysql` or `postgres` to create a build matrix with good coverage.


Versioning
----------

Major version zero (0.y.z) is for initial development. Anything may change at
any time. The public API should not be considered stable (implicitly mean, not
production ready ... yet).

Version 1.0.0 defines the public API (implying that it is production ready). The
way in which the version number is incremented after this release is dependent
on this public API and how it changes as per [Semantic Versioning
2.0.0][semver].

All the releases, with their respective changes are [listed here][8].


Contributing
------------

Want to contribute to the code? First, have a look at the guide in the
[CONTRIBUTING.md][9] file for the workflow.

Then, here's some Annotator documentation to help you get up to speed:

* [Annotator Storage][10] API specifications.
* [Annotator Store Plugin][11] documentation.

In summary, this gem helps implement a store for the plugin to interact with.

Any code contributors should be [listed here][12].


License
-------

[King'ori J. Maina][2] © 2014. The MIT License bundled therein is a permissive
license that is short and to the point. It lets people do anything they want as
long as they provide attribution and waive liability.


[annotator]: http://annotatorjs.org/
[semver]: http://semver.org

[1]: http://docs.annotatorjs.org/en/latest/hacking/plugin-development.html
[2]: http://kingori.co/
[3]: http://bundler.io/gemfile.html
[4]: http://bundler.io
[5]: https://rubygems.org/gems/annotator_store
[6]: http://rubydoc.info/gems/annotator_store/frames/
[7]: https://github.com/itsmrwave/annotator_store-gem/blob/master/CHANGELOG.md
[9]: https://github.com/itsmrwave/annotator_store-gem/blob/master/CONTRIBUTING.md
[8]: https://github.com/itsmrwave/annotator_store-gem/releases
[10]: http://docs.annotatorjs.org/en/v1.2.x/storage.html
[11]: http://docs.annotatorjs.org/en/v1.2.x/plugins/store.html
[12]: https://github.com/itsmrwave/annotator_store-gem/graphs/contributors
[13]: https://travis-ci.org/itsmrwave/annotator_store-gem
[14]: https://github.com/itsmrwave/annotator-store-demo
[15]: https://github.com/itsmrwave/annotator_store-gem/issues/1
[16]: http://rubygems.org/gems/appraisal
[17]: http://www.rubydoc.info/gems/appraisal
[18]: http://rubyonrails.org
[19]: https://github.com/itsmrwave/annotator_store-gem/issues/new
