/* global console */

function parsePostData(query) {
  var result = {};
  query.split("&").forEach(function(part) {
    var item = part.split("=");
    result[item[0]] = decodeURIComponent(item[1]);
  });
  return result;
}

function json(code, obj) {
  if (typeof code === "object") {
    obj = code;
    code = 200;
  }
  return [code, {"Content-Type": "application/json"}, JSON.stringify(obj)];
}

export default function() {
  var server = new Pretender(function() {
    this.post('/session', function(request) {
      var data = parsePostData(request.requestBody);

      if (data.password === 'correct') {
        return json({username: 'eviltrout'});
      }
      return json(400, {error: 'invalid login'});
    });

    this.get('/users/hp.json', function() {
      return json({"value":"32faff1b1ef1ac3","challenge":"61a3de0ccf086fb9604b76e884d75801"});
    });

    this.get('/session/csrf', function() {
      return json({"csrf":"mgk906YLagHo2gOgM1ddYjAN4hQolBdJCqlY6jYzAYs="});
    });

    this.get('/users/check_username', function(request) {
      if (request.queryParams.username === 'taken') {
        return json({available: false, suggestion: 'nottaken'});
      }
      return json({available: true});
    });

    this.post('/users', function(request) {
      return json({success: true});
    });
  });

  server.unhandledRequest = function(verb, path) {
    console.error('Unhandled request in test environment: ' + path + ' (' + verb + ')');
  };

  return server;
}
