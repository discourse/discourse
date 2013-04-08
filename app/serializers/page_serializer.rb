class PageSerializer < ApplicationSerializer

  attributes :name,
             :route,
             :page,
             :position,
             :user_id,
             :enabled,
             :id

  def name
    object['name']
  end

  def route
    object['route']
  end
  
  def page
    object['page']
  end
  
  def position
    object['position']
  end
  
  def user_id
    object['user_id']
  end
  
  def enabled
    object['enabled']
  end
  
  def id
    object['id']
  end

end
