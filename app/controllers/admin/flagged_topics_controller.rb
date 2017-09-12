require_dependency 'flag_query'

class Admin::FlaggedTopicsController < Admin::AdminController

  def index
    result = FlagQuery.flagged_topics

    render_json_dump(
      {
        flagged_topics: serialize_data(result[:flagged_topics], FlaggedTopicSummarySerializer),
        users: serialize_data(result[:users], BasicUserSerializer),
      },
      rest_serializer: true
    )
  end

end
