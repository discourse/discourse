var spinnerHTML = "<div class='spinner-wrap'><div class='spinner'><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div></div>";

Handlebars.registerHelper('loading-spinner', function() {
    return new Handlebars.SafeString(spinnerHTML);
});

export { spinnerHTML };
