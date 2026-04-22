class Admin::TagsController < Admin::BaseController
  def index
    tags = Tag.matching(params[:q]).map { |t| { id: t.id, text: t.name } }
    render json: tags
  end
end
