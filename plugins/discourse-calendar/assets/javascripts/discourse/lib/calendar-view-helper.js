// Helper functions for normalizing calendar view types between route params and FullCalendar

// Maps route view names to FullCalendar view names
export function normalizeViewForCalendar(routeView) {
  const viewMap = {
    agendaDay: "timeGridDay",
    agendaWeek: "timeGridWeek",
    month: "dayGridMonth",
    listNextYear: "listYear",
    year: "listYear",
    week: "timeGridWeek",
    day: "timeGridDay",
  };

  return viewMap[routeView] || routeView;
}

// Maps FullCalendar view names back to route view names
export function normalizeViewForRoute(calendarView) {
  const viewMap = {
    timeGridDay: "day",
    timeGridWeek: "week",
    dayGridMonth: "month",
    listYear: "year",
  };

  return viewMap[calendarView] || calendarView;
}
