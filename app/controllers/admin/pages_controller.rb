class Admin::PagesController < Admin::AdminController

  def index
    @pages = Page.all

    respond_to do |format|
      format.json { render json: @pages }
    end
  end

  def create
    @page = Page.new(params[:page])
    @page.user_id = current_user.id

    respond_to do |format|
      if @page.save
        format.json { render json: @page, status: :created}
      else
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @page = Page.find(params[:id])

    respond_to do |format|
      if @page.update_attributes(params[:page])
        format.json { head :no_content }
      else
        format.json { render json: @page.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @page = Page.find(params[:id])
    @page.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

end
