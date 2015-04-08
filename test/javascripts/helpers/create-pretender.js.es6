function parsePostData(query) {
  const result = {};
  query.split("&").forEach(function(part) {
    const item = part.split("=");
    result[item[0]] = decodeURIComponent(item[1]).replace(/\+/g, ' ');
  });
  return result;
}

function clone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

function response(code, obj) {
  if (typeof code === "object") {
    obj = code;
    code = 200;
  }
  return [code, {"Content-Type": "application/json"}, obj];
}

function success() {
  return response({ success: true });
}

const _widgets = [
  {id: 123, name: 'Trout Lure'},
  {id: 124, name: 'Evil Repellant'}
];

const _moreWidgets = [
  {id: 223, name: 'Bass Lure'},
  {id: 224, name: 'Good Repellant'}
];

function loggedIn() {
  return !!Discourse.User.current();
}

export default function() {

  const server = new Pretender(function() {

    const fixturesByUrl = {};

    // Load any fixtures automatically
    const self = this;
    Ember.keys(require._eak_seen).forEach(function(entry) {
      if (/^fixtures/.test(entry)) {
        const fixture = require(entry, null, null, true);
        if (fixture && fixture.default) {
          const obj = fixture.default;
          Ember.keys(obj).forEach(function(url) {
            fixturesByUrl[url] = obj[url];
            self.get(url, function() {
              return response(obj[url]);
            });
          });
        }
      }
    });

    this.get('/composer-messages', () => { return response([]); });

    this.get("/latest.json", () => {
      const json = fixturesByUrl['/latest.json'];

      if (loggedIn()) {
        // Stuff to let us post
        json.topic_list.can_create_topic = true;
        json.topic_list.draft_key = "new_topic";
        json.topic_list.draft_sequence = 1;
      }
      return response(json);
    });

    this.get("/t/id_for/:slug", function() {
      return response({id: 280, slug: "internationalization-localization", url: "/t/internationalization-localization/280"});
    });

    this.get("/404-body", function() {
      return [200, {"Content-Type": "text/html"}, "<div class='page-not-found'>not found</div>"];
    });

    this.get('/draft.json', function() {
      return response({});
    });

    this.post('/session', function(request) {
      const data = parsePostData(request.requestBody);

      if (data.password === 'correct') {
        return response({username: 'eviltrout'});
      }
      return response(400, {error: 'invalid login'});
    });

    this.get('/users/hp.json', function() {
      return response({"value":"32faff1b1ef1ac3","challenge":"61a3de0ccf086fb9604b76e884d75801"});
    });

    this.get('/session/csrf', function() {
      return response({"csrf":"mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs="});
    });

    this.get('/users/check_username', function(request) {
      if (request.queryParams.username === 'taken') {
        return response({available: false, suggestion: 'nottaken'});
      }
      return response({available: true});
    });

    this.post('/users', function() {
      return response({success: true});
    });

    this.get('/login.html', function() {
      return [200, {}, 'LOGIN PAGE'];
    });

    this.delete('/posts/:post_id', success);
    this.put('/posts/:post_id/recover', success);

    this.put('/posts/:post_id', (request) => {
      return response({ post: {id: request.params.post_id, version: 2 } });
    });

    this.put('/t/:slug/:id', (request) => {
      const data = parsePostData(request.requestBody);

      return response(200, { basic_topic: {id: request.params.id,
                                           title: data.title,
                                           fancy_title: data.title,
                                           slug: request.params.slug } });
    });

    this.post('/posts', function(request) {
      const data = parsePostData(request.requestBody);

      if (data.title === "this title triggers an error") {
        return response(422, {errors: ['That title has already been taken']});
      } else {
        return response(200, {
          success: true,
          action: 'create_post',
          post: {id: 12345, topic_id: 280, topic_slug: 'internationalization-localization'}
        });
      }
    });

    this.get('/widgets/:widget_id', function(request) {
      const w = _widgets.findBy('id', parseInt(request.params.widget_id));
      if (w) {
        return response({widget: w});
      } else {
        return response(404);
      }
    });

    this.put('/widgets/:widget_id', function(request) {
      const w = _widgets.findBy('id', parseInt(request.params.widget_id));
      return response({ widget: clone(w) });
    });

    this.get('/widgets', function(request) {
      let result = _widgets;

      const qp = request.queryParams;
      if (qp) {
        if (qp.name) { result = result.filterBy('name', qp.name); }
        if (qp.id) { result = result.filterBy('id', parseInt(qp.id)); }
      }

      return response({ widgets: result, total_rows_widgets: 4, load_more_widgets: '/load-more-widgets' });
    });

    this.get('/load-more-widgets', function() {
      return response({ widgets: _moreWidgets, total_rows_widgets: 4, load_more_widgets: '/load-more-widgets' });
    });

    this.delete('/widgets/:widget_id', success);

    this.post('/topics/timings', function() {
      return response(200, {});
    });
  });

  server.prepareBody = function(body){
    if (body && typeof body === "object") {
      return JSON.stringify(body);
    }
    return body;
  };

  server.unhandledRequest = function(verb, path) {
    const error = 'Unhandled request in test environment: ' + path + ' (' + verb + ')';
    window.console.error(error);
    throw error;
  };

  server.checkPassthrough = function(request) {
    return request.requestHeaders['Discourse-Script'];
  };

  return server;
}
