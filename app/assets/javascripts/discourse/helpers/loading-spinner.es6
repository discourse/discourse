Handlebars.registerHelper('loading-spinner', function(property, options) {
    var spinner = "<div class='spinner-wrap'><div class='spinner'><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div></div>";
    return new Handlebars.SafeString(spinner);
});
