const _widgets = [
  {id: 123, name: 'Trout Lure'},
  {id: 124, name: 'Evil Repellant'}
];

const _moreWidgets = [
  {id: 223, name: 'Bass Lure'},
  {id: 224, name: 'Good Repellant'}
];

const fruits = [{id: 1, name: 'apple', farmer_id: 1, color_ids: [1,2], category_id: 4},
                {id: 2, name: 'banana', farmer_id: 1, color_ids: [3], category_id: 3},
                {id: 3, name: 'grape', farmer_id: 2, color_ids: [2], category_id: 5}];

const farmers = [{id: 1, name: 'Old MacDonald'},
                 {id: 2, name: 'Luke Skywalker'}];

const colors = [{id: 1, name: 'Red'},
                {id: 2, name: 'Green'},
                {id: 3, name: 'Yellow'}];

export default function(helpers) {
  const { response, success, parsePostData } = helpers;

  this.get('/fruits/:id', function() {
    const fruit = fruits[0];
    return response({ __rest_serializer: "1", fruit, farmers, colors });
  });

  this.get('/fruits', function() {
    return response({ __rest_serializer: "1", fruits, farmers, colors, extras: {hello: 'world'} });
  });

  this.get('/widgets/:widget_id', function(request) {
    const w = _widgets.findBy('id', parseInt(request.params.widget_id));
    if (w) {
      return response({widget: w});
    } else {
      return response(404);
    }
  });

  this.post('/widgets', function(request) {
    const widget = parsePostData(request.requestBody).widget;
    widget.id = 100;
    return response(200, {widget});
  });

  this.put('/widgets/:widget_id', function(request) {
    const widget = parsePostData(request.requestBody).widget;
    return response({ widget });
  });

  this.put('/cool_things/:cool_thing_id', function(request) {
    const cool_thing = parsePostData(request.requestBody).cool_thing;
    return response({ cool_thing });
  });

  this.get('/widgets', function(request) {
    let result = _widgets;

    const qp = request.queryParams;
    if (qp) {
      if (qp.name) { result = result.filterBy('name', qp.name); }
      if (qp.id) { result = result.filterBy('id', parseInt(qp.id)); }
    }

    return response({ widgets: result,
                      total_rows_widgets: 4,
                      load_more_widgets: '/load-more-widgets',
                      refresh_widgets: '/widgets?refresh=true' });
  });

  this.get('/load-more-widgets', function() {
    return response({ widgets: _moreWidgets, total_rows_widgets: 4, load_more_widgets: '/load-more-widgets' });
  });

  this.delete('/widgets/:widget_id', success);
};
