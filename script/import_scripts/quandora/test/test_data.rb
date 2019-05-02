  # frozen_string_literal: true
  BASES = '{
    "type" : "kbase",
    "data" : [ {
      "objectId" : "90b1ccf3-35aa-4d6f-848e-e7c122d92c58",
      "objectName" : "hotdogs",
      "title" : "Hot Dogs",
      "description" : "This knowledge base is for questions about Hot Dogs"
    } ]
  }'

  QUESTIONS = '{
    "type": "question-search-result",
    "data": {
      "totalSize": 445,
      "offset": 0,
      "limit": 1000,
      "result": [ {
        "uid": "dd2cf490-f564-4147-9943-57682c7fac73",
        "title": "How can we improve the office?",
        "summary": "Hi everyone, I&rsquo;d love to hear your suggestions about how we can make our office a more pleasant place to work",
        "votes": 2,
        "views": 107,
        "answers": 5,
        "commentsCount": 3,
        "created": "2013-01-06T18:24:54.62Z",
        "modified": "2015-05-03T00:52:45.63Z",
        "authorId": "24599c93-0a83-4099-982f-d0d708ea3178",
        "baseId": "90b1ccf3-35aa-4d6f-848e-e7c122d92c58",
        "prettyUrl": "https://mydomain.quandora.com/general/q/de20ed0a5fe548a59c14d854f9af99f1/How-can-we-improve-the-office",
        "accepted": null,
        "author": {
          "uid": "24599c93-0a83-4099-982f-d0d708ea3178",
          "name": "24599c93-0a83-4099-982f-d0d708ea3178",
          "email": "flast@mydomain.com",
          "firstName": "First",
          "lastName": "Last",
          "title": "Member",
          "score": 236,
          "disabled": false,
          "badgeCount": [3,0,0],
          "avatarUrl": "//www.gravatar.com/avatar/fdf8bd4205dc7ad908ea0578a111cb89?d=mm&s=%s"
        },
        "tags": [ {
          "uid": "88a08f00-3038-4e96-8c26-4a777b46871c",
          "name": "office",
          "category": null
        }]
      }]
    }
  }'

  QUESTION = '{
  "type" : "question",
  "data" : {
    "uid" : "de20ed0a-5fe5-48a5-9c14-d854f9af99f1",
    "title" : "How can we improve the office?",
    "votes" : 2,
    "views" : 107,
    "answers" : 5,
    "commentsCount" : 3,
    "created" : "2013-01-06T18:24:54.62Z",
    "modified" : "2015-05-03T00:52:45.63Z",
    "authorId" : "043c8d91-26f7-44c7-acfa-179f06a4e998",
    "baseId" : "7583b6df-2090-46fd-97b5-cdde072ec34e",
    "prettyUrl" : "https://mydomain.quandora.com/general/q/de20ed0a5fe548a59c14d854f9af99f1/How-can-we-improve-the-office",
    "accepted" : null,
    "content" : "<p>Hi everyone,</p> \n<p>I\'d love to hear your suggestions about how we can make our office a more pleasant place to work.</p> \n<p>What things are we missing from our kitchen or supply closet?</p> \n<p>If you don\'t regularly come to the office, and what do you think would make you more likely to make the commute?</p> \n<p>Thanks!</p>",
    "contentType" : "markdown",
    "answersList" : [ {
      "uid" : "78e7dc82-fe0f-4687-8ed9-6ade23d95164",
      "contentType" : "markdown",
      "content" : "<p>The most value I get out of coming to the office is hearing about weird techy glitches, or announcements that the company has to make.</p> \n<p>The bulletin board, at least in Ohio, seems to have died off a bit. It would be easy to say that people are intimidated by the large group, but in some meetings I think there\'s another problem: it\'s often the case that people just say \'come and grab me after the meeting\'. I\'m sure that works well, but I like it when a summary of the solution arrives back via email or at the next meeting, so that the whole office can benefit from the knowledge transfer.</p>",
      "comments" : [ ],
      "votes" : 3,
      "created" : "2013-01-07T04:59:56.26Z",
      "accepted" : false,
      "authorId" : "acfd09c6-8bf8-4342-98de-3d7fc4c60ec0",
      "author" : {
        "uid" : "acfd09c6-8bf8-4342-98de-3d7fc4c60ec0",
        "name" : "acfd09c6-8bf8-4342-98de-3d7fc4c60ec0",
        "email" : "hharry@mydomain.com",
        "firstName" : "Harry",
        "lastName" : "Helpful",
        "title" : "Member",
        "score" : 1615,
        "disabled" : false,
        "badgeCount" : null,
        "avatarUrl" : "//www.gravatar.com/avatar/e3cbc264af6d2392b7f323cebbbcfea6?d=mm&s=%s"
      }
    }, {
      "uid" : "b6864e72-1a03-4f49-aa7f-d2781b14f69c",
      "contentType" : "markdown",
      "content" : "<p>For Ohio: i don\'t know if you\'ve already tried this, but I recommend doing the meetings in the beginning of the day. That way people are more likely to come into the office early, rather than after lunch :)</p>",
      "comments" : [ {
        "author" : {
          "uid" : "204973f4-2dfe-494c-b1b2-3cd1cbac34f0",
          "name" : "204973f4-2dfe-494c-b1b2-3cd1cbac34f0",
          "email" : "eexcited@mydomain.com",
          "firstName" : "Eddy",
          "lastName" : "Excited",
          "title" : "Member",
          "score" : 516,
          "disabled" : false,
          "badgeCount" : null,
          "avatarUrl" : "//www.gravatar.com/avatar/baa5f96720477108e685d38f5a7fa21c?d=mm&s=%s"
        },
        "created" : "2016-01-22T15:38:55.91Z",
        "text" : "Great idea! I think more people will overlap here if we start our days at the same time.",
        "hash" : "7f45b063f8f52eead80a784ca37e901a"
      } ],
      "votes" : 2,
      "created" : "2013-01-08T16:49:32.80Z",
      "accepted" : false,
      "authorId" : "da0a6658-fa06-420a-9027-7a8051e4ec29",
      "author" : {
        "uid" : "da0a6658-fa06-420a-9027-7a8051e4ec29",
        "name" : "da0a6658-fa06-420a-9027-7a8051e4ec29",
        "email" : "ssmartypants@mydomain.com",
        "firstName" : "Sam",
        "lastName" : "Smarty-Pants",
        "title" : "Member",
        "score" : 3485,
        "disabled" : false,
        "badgeCount" : null,
        "avatarUrl" : "//www.gravatar.com/avatar/e0be54fafea799f30abb6eacd2459cf6?d=mm&s=%s"
      }
    } ],
    "comments" : [ {
      "author" : {
        "uid" : "acfd09c6-8bf8-4342-98de-3d7fc4c60ec0",
        "name" : "acfd09c6-8bf8-4342-98de-3d7fc4c60ec0",
        "email" : "hhelpful@mydomain.com",
        "firstName" : "Harry",
        "lastName" : "Helpful",
        "title" : "Member",
        "score" : 236,
        "disabled" : false,
        "badgeCount" : [ 3, 0, 0 ],
        "avatarUrl" : "//www.gravatar.com/avatar/e3cbc264af6d2392b7f323cebbbcfea6?d=mm&s=%s"
      },
      "created" : "2016-01-20T15:38:55.91Z",
      "text" : "Also, what hopes and expectations do you have of the new meeting space that we will be starting to use this week?",
      "hash" : "226dbd023cc4e786bf1e7bc08989bde7"
    }, {
      "author" : {
        "uid" : "7fcdc8ee-ab92-43a9-84a6-665aa4edbb49",
        "name" : "7fcdc8ee-ab92-43a9-84a6-665aa4edbb49",
        "email" : "ggreatful@mydomain.com",
        "firstName" : "Greta",
        "lastName" : "Greatful",
        "title" : "Member",
        "score" : 516,
        "disabled" : false,
        "badgeCount" : null,
        "avatarUrl" : "//www.gravatar.com/avatar/d6027aecba638fc8c402c6138e799007?d=mm&s=%s"
      },
      "created" : "2016-01-21T15:38:55.91Z",
      "text" : "I love coming into the office.  The view is great, the food is wonderful, and I get to hang out with some awesome people!",
      "hash" : "7f45b063f8f52eead80a784ca37e901a"
    } ],
    "author" : {
      "uid" : "8c07ba39-1e2b-406f-b3cf-3da78431d399",
      "name" : "8c07ba39-1e2b-406f-b3cf-3da78431d399",
      "email" : "iinquisitive@mydomain.com",
      "firstName" : "Ida",
      "lastName" : "Inquisitive",
      "title" : "Member",
      "score" : 236,
      "disabled" : false,
      "badgeCount" : [ 3, 0, 0 ],
      "avatarUrl" : "//www.gravatar.com/avatar/187f4bff7780e4a12b727c3ad81cfbac?d=mm&s=%s"
    },
    "tags" : [ {
      "uid" : "53f65082-f081-4fc9-9bd5-a739599ee2b3",
      "name" : "office",
      "category" : null
    } ]
  }
}'
