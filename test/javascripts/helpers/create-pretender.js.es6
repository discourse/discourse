function parsePostData(query) {
  var result = {};
  query.split("&").forEach(function(part) {
    var item = part.split("=");
    result[item[0]] = decodeURIComponent(item[1]);
  });
  return result;
}

function response(code, obj) {
  if (typeof code === "object") {
    obj = code;
    code = 200;
  }
  return [code, {"Content-Type": "application/json"}, obj];
}

export default function() {
  var server = new Pretender(function() {

    // Load any fixtures automatically
    var self = this;
    Ember.keys(require._eak_seen).forEach(function(entry) {
      if (/^fixtures/.test(entry)) {
        var fixture = require(entry, null, null, true);
        if (fixture && fixture.default) {
          var obj = fixture.default;
          Ember.keys(obj).forEach(function(url) {
            self.get(url, function() {
              return response(obj[url]);
            });
          });
        }
      }
    });

    this.get("/404-body", function() {
      return [200, {"Content-Type": "text/html"}, "<div class='page-not-found'>not found</div>"];
    });

    this.get("/search", function() {
      return response([ { type: "topic", more: true, results: [ { url: "some-url" } ] } ]);
    });

    this.get('/draft.json', function() {
      return response({});
    });

    this.post('/session', function(request) {
      var data = parsePostData(request.requestBody);

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
  });


  server.prepareBody = function(body){
    if (body && typeof body === "object") {
      return JSON.stringify(body);
    }
    return body;
  };

  server.unhandledRequest = function(verb, path) {
    var error = 'Unhandled request in test environment: ' + path + ' (' + verb + ')';
    window.console.error(error);
    throw error;
  };

  return server;
}
