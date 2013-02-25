Rails.application.routes.draw do

  put 't/:slug/:topic_id/complete' => 'topics#complete', :constraints => {:topic_id => /\d+/}

end
